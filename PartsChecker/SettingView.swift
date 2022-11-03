//
//  SettingView.swift
//  PartsChecker
//
//  Created by 隠塚永治 on 2022/11/07.
//

import SwiftUI

struct SettingView: View {
    @EnvironmentObject var vm: ViewModel
    var body: some View {
        NavigationView {
            VStack(){
                Spacer()
                VStack(alignment: .leading){
                    Text("サーバー URL")
                    //.padding()
                    TextField("Server URL", text: $vm.baseURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    //.padding()
                }
                .padding()
                VStack(alignment: .leading) {
                    Text("認証コード")
                    TextField("Auth Code", text: $vm.authCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding()
                VStack(alignment: .leading) {
                    Text("API クエリ")
                    TextField("API Query", text: $vm.query)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding()
                VStack(alignment: .leading) {
                    Text("カートリッジ先頭文字(正規表現)")
                    TextField("Cartrige First Char", text: $vm.cartridgeFirstChar)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding()
                Spacer()
            }
        }
        .navigationTitle("設定 ")
    }
}

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView()
    }
}

