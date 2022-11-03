//
//  DataScannerView.swift
//  PartsChecker
//
//  Created by E.O on 2022/11/05.
//

import SwiftUI
import Foundation
import VisionKit

struct DataScannerView: UIViewControllerRepresentable {
    // ViewModel の参照
    @EnvironmentObject var vm: ViewModel
    // Binding 変数が変更されるたびに読み出される
    // 認識されたアイテムの配列
    @Binding var recognizedItems: [RecognizedItem]
    // 認識されたデータをキャプチャしたイメージ
    @Binding var distImage: UIImage?
    // 認識するデータのタイプ text / barcode
    let recognizedDataType: DataScannerViewController.RecognizedDataType
    
    // UIView をラップ
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController (
            recognizedDataTypes: [recognizedDataType],      // スキャンタイプ [.text(), .barcode()]
            qualityLevel: .accurate,                        // スキャンクオリティ .fast, .balance, .accurate
            recognizesMultipleItems: false,                 // 映像内のアイテムを全てスキャンするか
            isHighFrameRateTrackingEnabled: false,          // 映像内のスキャンを行う頻度
            isPinchToZoomEnabled: true,                     // ピンチズームを使用できるか
            isHighlightingEnabled: true                     // 認識した項目の周辺にハイライトを表示するか
        )
        return vc
    }
    
    // UIViewの更新
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        uiViewController.delegate = context.coordinator
        // 画面の文字列検索開始フラグ
        if vm.scanEnable {
            // スキャン中でない場合
            if !uiViewController.isScanning {
                // スキャン開始
                // try の後の ? : 成功しなかった場合、無視して次へ進む
                try? uiViewController.startScanning()
            // スキャンイネーブルがディスイネーブルされた時
            } else {
                // まだスキャンしている場合
                if uiViewController.isScanning {
                    // 画面キャプチャの指示があったら
                    if vm.getCapture {
                        // capturePhoto() は Task で処理 -> 使い方がわからずに時間がかかった
                        Task {
                            // capturePhoto() は async throw  なので、try? await をつける
                            if let uiImage = try? await uiViewController.capturePhoto() {
                                // バインディングしている変数へ保持
                                distImage = uiImage
                                // キャプチャフラグを落とす
                                vm.getCapture.toggle()
                            }
                        }
                        
                    }
                    // スキャンの終了
                    uiViewController.stopScanning()
                    uiViewController.dismiss(animated: true)
                }
            }
        }
    }
    
    // コーディネイトする変数の宣言と取得
    func makeCoordinator() -> Coordinator {
        Coordinator(recognizedItems: $recognizedItems)
    }
    
    // 終了処理
    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }
    
    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        @Binding var recognizedItems: [RecognizedItem]
        
        init(recognizedItems: Binding<[RecognizedItem]>) {
            self._recognizedItems = recognizedItems
        }
        
        // Itemをタップした場合の処理
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            
        }
        
        // Itemが追加された時の処理
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            // 認識したアイテムを追加
            recognizedItems = addedItems
        }
        
        // Itemがアップデートされた時の処理
        // didAdd との違いは？
        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate pdatedItems: [RecognizedItem]) {
            
        }
        
        // Itemの削除
        func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allIetms: [RecognizedItem]) {
            // filter -> 条件に合うものだけを返す
            recognizedItems = recognizedItems.filter { item in
                // removedItemsにない物が残される
                !removedItems.contains(where: {$0.id == item.id})
            }
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            print("unavailable error")
        }
        
    }
}
