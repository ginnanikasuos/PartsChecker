//
//  APIClient.swift
//  PartsChecker
//
//  Created by 隠塚永治 on 2022/11/05.
//

import SwiftUI

// サーバーからのレスポンスデータ型
struct Cartridges: Codable {
    var cartridges: [Cartridge]
}
struct Cartridge: Codable {
    var cartridge: String
    var parts: String
    var result: Bool
    
    static let defaultCartridge = Cartridge(cartridge: "XXXX-XXXX-XXXX", parts: "SAMPLE-PARTS", result: true)
}

// API アクセスエラー
enum APIClientError: Error {
    case authorizationError
    case invalidURL
    case responseError
    case responseDataError
    case parseError(Error)
    case serverError(Error)
    case badStatus(statusCode: Int)
    case noData
}

final class APIClient {
    // ViewModel の参照
    @EnvironmentObject var vm: ViewModel
    // Server REST API 関係
    // task 処理
    var task: Task<(), Never>? = nil
    
    // サーバーからレスポンスと共に帰ってきたデータ
    var responseData: [Cartridge] = [.defaultCartridge]
    // サーバーからのデータを受信
    func taskApiGet(query: String) {
        task = Task {
            try? await apiGet(query: query)
        }
    }
    
    func apiGet(query: String) async throws {
        guard let url = URL(string: vm.baseURL + "?query=\(query)") else {
            throw APIClientError.invalidURL
        }
        // Authorization Code の確認
        if vm.authCode == "" {
            print("Authorization is None")
            throw APIClientError.authorizationError
        }
        // リクエストインスタンス作成
        var request = URLRequest.init(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = [
            "Content-Type": "application/json",
            "Authorization": "\(vm.authCode)",
        ]
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let res = response as? HTTPURLResponse else {
            print("response error")
            throw APIClientError.responseError
        }
        if res.statusCode != 200 {
            print("status error : \(res.statusCode)")
            throw APIClientError.badStatus(statusCode: res.statusCode)
        }
        guard let decodedData = try? JSONDecoder().decode(Cartridges.self, from: data) else {
            print("response data error")
            throw APIClientError.responseDataError
        }
        vm.responseData = decodedData.cartridges
    }
    
    // サーバーへデータ送信
    func taskApiPost(cartridge: String, parts: String) {
        task = Task {
            try? await apiPost(cartridge: cartridge, parts: parts)
        }
    }
    
    func apiPost(cartridge: String, parts: String) async throws {
        // Authorization Code の確認
        if vm.authCode == "" {
            print("Authorization is None")
            throw APIClientError.authorizationError
        }
        // サーバーURL確認
        guard let url = URL(string: vm.baseURL) else {
            throw APIClientError.invalidURL }
        // リクエストインスタンス作成
        var request = URLRequest.init(url: url)
        // リクエスト設定
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = [
            "Content-Type": "application/json",
            "Authorization": "\(vm.authCode)",
        ]
        // 転送するデータ
        let params: [String: String] = ["cartridge": cartridge, "parts": parts]
        // Json 形式のデータ生成
        do {
            let httpBody = try JSONSerialization.data(withJSONObject: params, options: [])
            request.httpBody = httpBody
        } catch {
            print(error.localizedDescription)
        }
        // レスポンスの検証
        let (data, response) = try await URLSession.shared.data(for: request)
        // レスポンスをキャスト
        guard let res = response as? HTTPURLResponse else {
            print("response error")
            throw APIClientError.responseError
        }
        if res.statusCode != 200 {
            print("status error : \(res.statusCode)")
            throw APIClientError.badStatus(statusCode: res.statusCode)
        }
        
        guard let decodedData = try? JSONDecoder().decode(Cartridges.self, from: data) else {
            print("response data error")
            throw APIClientError.responseDataError
        }
        vm.responseData = decodedData.cartridges
    }
}
