//
//  ContentView.swift
//  PartsChecker
//
//  Created by E.O on 2022/11/03.
//

import SwiftUI
import VisionKit

struct ContentView: View {
    @EnvironmentObject var vm: ViewModel
    // 画面に表示する文字列
    @State var recognizedText: String = ""
    // アプリ設定画面への遷移フラグ
    @State private var showSettingView: Bool = false
    // 静止画像
    @State var uiImage: UIImage? = nil
    
    @State var showingSettingView: Bool = false
    
    
    // フォントの統一
    private let fontType: Font = .headline
    
    // APIClient インスタンス
    private var apiClient = APIClient()
    
    // スキャンできるかの状況に応じて状態遷移
    var body: some View {
        switch vm.dataScannerAccessStatusType {
        case .scannerAvailable:
            mainView
            
        case .cameraNotAvailable:
            Text("カメラがありません。")
        case .scannerNotAvailable:
            Text("データスキャンをサポートしていません。")
        case .cameraAccessNotGranted:
            Text("カメラへのアクセスを許可してください。")
        case .notDetermined:
            Text("カメラへのアクセス中")
        }
    }
    
    // メイン画面
    var mainView: some View {
        // 表示サイズを指定する為に Geometry を使用
        GeometryReader { geometry in
            VStack {
                // カメラ画像に重ねて検出した文字列を表示
                if let uiImage = vm.recognizedImage {
                    Image(uiImage: uiImage)
                    // 画面の上部 1/3 のスペースに表示
                        .resizable()
                        .scaledToFill()
                        .frame(height: geometry.size.height / 3)
                        .clipped()
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 6)
                } else {
                    // データスキャン画像を表示
                    DataScannerView(
                        recognizedItems: $vm.recognizedItems,
                        distImage: $vm.recognizedImage,
                        recognizedDataType: vm.recognizedDataType
                    )
                    // 画面の上部 1/3 のスペースに表示
                    .frame(height: geometry.size.height / 3)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 6)
                    // view の id値が変わると view がリセットされる
                    .id(vm.dataScannerViewID)
                }
                // 期待した文字列やバーコードを検出したら、画像を保持する
                if let distText = vm.getDistText() {
                    Text(distText)
                        .background(.blue.opacity(0.5))
                        .foregroundColor(Color.red)
                        .frame(maxWidth: .infinity)
                        .font(.title)
                        // 文字列を検出した位置に表示
                        .position(x: vm.boundingBox.midX, y: vm.boundingBox.midY)
                } else if let recognizedText = vm.recognizedText {
                    // 文字列を検出している場合は、検出した位置に文字列を表示
                    Text(recognizedText)
                        .background(.blue.opacity(0.5))
                        .foregroundColor(Color.red)
                        .frame(maxWidth: .infinity)
                        .font(.title2)
                        // 文字列を検出した位置に表示
                        .position(x: vm.boundingBox.midX, y: vm.boundingBox.midY)
                }
                // 操作画面
                naviView
                    // 残りの 2/3 に表示する
                    .frame(height: geometry.size.height * 2 / 3)
            }
        }
    }
    // 操作画面
    private var naviView: some View {
        // アプリ設定画面へ遷移
        GeometryReader { geometry in
            NavigationView {
                VStack {
                    // 間隔を揃える為 List を使用
                    List {
                        NavigationLink {
                            SettingView()
                        } label: {
                            HStack {
                                Spacer()
                                Text("設定")
                                Image(systemName: "gearshape")
                            }
                        }
                        // 操作指示、ステータス表示
                        Text("\(vm.naviText)")
                            .font(fontType)
                            .lineLimit(2)
                        
                        // 検出したカートリッジを表示するフィールド
                        TextField("カートリッジ", text: $vm.cartridgeNo)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(fontType)
                        // 検出した部品を表示するフィールド
                        TextField("部品型番", text: $vm.partsStandard)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(fontType)
                        HStack {
                            Spacer()
                            Button(action: {
                                vm.fieldClear()
                            }){
                                Text("クリア")
                                    .font(fontType)
                            }
                            Spacer()
                            Button(action: {
                                vm.scanStart()
                            }){
                                Text("スキャン")
                                    .font(fontType)
                            }
                            Spacer()
                            Button(action: {
                                apiClient.taskApiGet(query: "cartridge=\(vm.cartridgeNo)")
                            }){
                                Text("送信")
                                    .font(fontType)
                            }
                            Spacer()
                        }
                        Picker("スキャンタイプ", selection: $vm.scanType){
                            Text("バーコード").tag(ScanType.barcode)
                                .font(fontType)
                            Text("テキスト").tag(ScanType.text)
                                .font(fontType)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: vm.scanType) {_ in vm.recognizedItems = []}
                    }
                }
            }
        }
    }
}
