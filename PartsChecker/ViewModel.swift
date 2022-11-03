//
//  ViewModel.swift
//  PartsChecker
//
//  Created by 隠塚永治 on 2022/11/03.
//

import Foundation
import SwiftUI
import VisionKit
import AVKit

// スキャンするタイプ
enum ScanType: String {
    case barcode, text
}

// データをスキャンできる状態にあるか監視
enum DataScannerAccessStatusType {
    case notDetermined
    case cameraAccessNotGranted
    case cameraNotAvailable
    case scannerAvailable
    case scannerNotAvailable
}

enum scanStatus {
    case scanCartridge      // カートリッジスキャン
    case getCartridge       // カートリッジナンバーを取得
    case sendCartridge      // カートリッジナンバーをサーバーへ送信 (GET)
    case getParts           // カートリッジに対応した部品型番を受信
    case scanParts          // 部品型番をスキャン
    case sendAll            // カートリッジナンバーと部品型番をサーバーへ送信 (POST)
    case getResults         // 結果を受信
}


@MainActor
final class ViewModel: ObservableObject {
    // スキャンステータス
    @Published var scanState: scanStatus = .scanCartridge
    // @Published の変数が変更されると全てのViewで更新される
    // スキャンが実行される環境か
    @Published var dataScannerAccessStatusType: DataScannerAccessStatusType = .notDetermined
    // 認識されたItemの配列
    @Published var recognizedItems: [RecognizedItem] = []
    // 認識した時点の静止画
    @Published var recognizedImage: UIImage?
    // スキャンタイプ
    @Published var scanType: ScanType = .barcode
    // スキャンするアイテムのタイプを決定
    var recognizedDataType: DataScannerViewController.RecognizedDataType {
        scanType == .barcode ? .barcode() : .text(languages: ["ja"], textContentType: .none)
    }
    // スキャンデータの情報をハッシュ値として、種別を判定
    // text or barcode のみで判定 -> スキャン画面が再描画される
    var dataScannerViewID: Int {
        var hasher = Hasher()
        hasher.combine(scanType)
        return hasher.finalize()
    }
    
    // DataScanner がサポートされているか
    private var isScannerAvailable : Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }
    
    // main でタスク処理されている、スキャンの状態監視
    func requestDataScannerAccessStatus() async {
        // カメラを使用できるか
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            dataScannerAccessStatusType = .cameraNotAvailable
            return
        }
        // デバイスをビデオに設定した戻り値で状態判別
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: // カメラの使用が許可されている
            // DataScanner が使えるか判定
            dataScannerAccessStatusType = isScannerAvailable ? .scannerAvailable : .scannerNotAvailable
        case .restricted, .denied: // カメラの使用が許可されていない
            dataScannerAccessStatusType = .cameraAccessNotGranted
        case .notDetermined:
            // ビデオフレームへのアクセスを求める
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            // 戻り値によって判別
            if granted {
                dataScannerAccessStatusType = isScannerAvailable ? .scannerAvailable : .scannerNotAvailable
            } else {
                dataScannerAccessStatusType = .cameraAccessNotGranted
            }
        default: break
        }
    }
    // スキャン有効／無効フラグ
    var scanEnable = true
    // 画像キャプチャフラグ
    var getCapture = false
    // 比較元となるテキスト
    var sourceText: String = ""
    // 比較元を含む文字列
    var distText: String?
    // 検出文字列の位置
    var boundingBox = CGRect.zero
    // 文字列検出
    // 文字列の検出は、スキャンのステータスで変わる
    var recognizedText: String {
        var string: String = ""
        // 検出アイテムがない場合
        if recognizedItems.count == 0 {
            return string
        }
        // アイテムの先頭に対して処理
        if let item = recognizedItems.first {
            // バーコードかテキストかの選択
            switch item {
            case .text(let text):
                string = text.transcript
            case .barcode(let code):
                string = code.payloadStringValue ?? ""
            default:
                break
            }
            // 文字列がなければ終了
            if string == "" { return string }
            // 改行までを切り取り
            string = string.components(separatedBy: .newlines)[0]
            // 空白を埋める
            let del_space: Set<Character> = [" ","　"]
            string.removeAll(where: {del_space.contains($0) })
            // 文字列を囲む四角形を生成
            boundingBox = boundingBoxFromBounds(bnd: item.bounds)
        } else {
            return string
        }
        // カートリッジ番号のスキャン
        if scanState == .scanCartridge {
            if cartridgeFirstChar != "" {
                guard let regex = try? NSRegularExpression(pattern: cartridgeFirstChar) else {
                    string = "カートリッジ先頭文字列が不正です。"
                    return string
                }
                
                // 正規表現との比較
                let checkingResults = regex.matches(in: string, range: NSRange(location: 0, length: string.count))
                if checkingResults.count > 0 {
                    cartridgeNo = string
                    scanState = .getCartridge
                }
            }
        }
        return string
    }
    // 検索文字列と同じ文字が見つかった場合、文字列を返す
    func getDistText() -> String? {
        // すでに確定している場合
        if let _ = distText {
            return distText
        } else if sourceText != "" {
            let tmpText = checkIncludeCharacters(recogText: recognizedText, sourceText: sourceText)
            distText = tmpText
            return distText
        }
        return nil
    }
    
    // 文字列が一致するか検査する関数
    func checkIncludeCharacters(recogText: String, sourceText: String) -> String? {
        var tmpText: String? = nil
        if recogText.contains(sourceText) {
            scanEnable = false
            getCapture = true
            // 検索文字列のみ抽出
            if let range = recogText.range(of: sourceText) {
                // 一致した部分のみ抽出
                tmpText = String(recogText[range])
            } else {
                tmpText = recogText
            }
        }
        return tmpText
    }
    
    
    // 表示関係
    // 操作表示文字列
    var naviText: String = ""
    
    // API 関係
    // baseURL
    @AppStorage("baseURL") var baseURL = "https:/ikasuos.org/parts-api/api/"
    // POST URL+Query
    @AppStorage("postURL") var postURL =
    // 秘密キー
    @AppStorage("authCode") var authCode = "Bearer 3|ZVefJvULsY08unq4x2NadT5QkLTHrDHWjt592mos"
    // カートリッジの先頭文字列
    @AppStorage("cartridgeFirstChar") var cartridgeFirstChar = "^[SSY|ALY|ZSY]-[0-9]{3}-[0-9]{7}[A-Z]"
    // API クエリ
    @AppStorage("query") var query = "SSY-"
    // カートリッジナンバー
    var cartridgeNo = ""
    // 部品規格
    var partsStandard = ""
    // サーバーからのレスポンスデータ
    var responseData: [Cartridge]?
    
    // 読み込んだテキストフィールドのデータをクリア
    func fieldClear() {
        if partsStandard != "" {
            partsStandard = ""
        } else if cartridgeNo != "" {
            cartridgeNo = ""
        }
        recognizedImage = nil
        scanEnable = true
    }
    
    // スキャン開始
    func scanStart() {
        scanEnable = true
    }
    
    // 検出文字を囲むエリア
    private func boundingBoxFromBounds(bnd: RecognizedItem.Bounds) -> CGRect {
        let xs = [bnd.topLeft.x, bnd.topRight.x, bnd.bottomLeft.x, bnd.bottomRight.x]
        let ys = [bnd.topLeft.y, bnd.topRight.y, bnd.bottomLeft.y, bnd.bottomRight.y]
        return CGRect(
            x: xs.min()!,
            y: ys.min()!,
            width: xs.max()! - xs.min()!,
            height: ys.max()! - ys.min()!
        )
    }
    
}
