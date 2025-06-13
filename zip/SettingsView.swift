import SwiftUI


// SettingsView 保持不变
struct SettingsView: View {
    @ObservedObject var viewModel: CompressionViewModel
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
        Form {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.operationType == .compress {
                    // 压缩格式选择
                    HStack(alignment: .center) {
                        Text("压缩格式")
                                .foregroundColor(.black)
                            .frame(width: 90, alignment: .leading)
                        Menu {
                            ForEach([
                                ArchiveType.zip,
                                ArchiveType.sevenZip,
                                ArchiveType.tar,
                                ArchiveType.xz
                            ], id: \.self) { type in
                                Button(type.fileExtension) {
                                    viewModel.selectedArchiveType = type
                                }
                            }
                        } label: {
                            Text(viewModel.selectedArchiveType.fileExtension)
                                    .foregroundColor(.black)
                                .frame(width: 160, alignment: .leading)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white)
                                    .cornerRadius(4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                        }
                    }
                    // 压缩级别选择
                    HStack(alignment: .center) {
                        Text("压缩级别")
                                .foregroundColor(.black)
                            .frame(width: 90, alignment: .leading)
                        Menu {
                            ForEach([
                                CompressionLevel.none,
                                CompressionLevel.fast,
                                CompressionLevel.normal,
                                CompressionLevel.maximum
                            ], id: \.self) { level in
                                Button(level.description) {
                                    viewModel.settings.compressionLevel = level
                                }
                            }
                        } label: {
                            Text(viewModel.settings.compressionLevel.description)
                                    .foregroundColor(.black)
                                .frame(width: 160, alignment: .leading)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white)
                                    .cornerRadius(4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                        }
                    }
                }
                // 密码设置
                HStack(alignment: .center) {
                    Toggle("使用密码保护", isOn: $viewModel.settings.usePassword)
                            .foregroundColor(.black)
                        .frame(width: 250, alignment: .leading)
                }
                if viewModel.settings.usePassword {
                    HStack(alignment: .center) {
                        Text("输入密码")
                                .foregroundColor(.black)
                            .frame(width: 90, alignment: .leading)
                        SecureField("", text: $viewModel.settings.password)
                                .foregroundColor(.black)
                            .frame(width: 160, alignment: .leading)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white)
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                    }
                }
                // 完成后的操作
                HStack(alignment: .center) {
                    Toggle("完成后打开目标文件夹", isOn: $viewModel.settings.openAfterCompletion)
                            .foregroundColor(.black)
                        .frame(width: 250, alignment: .leading)
                }
                HStack(alignment: .center) {
                    Toggle("完成后删除源文件", isOn: $viewModel.settings.deleteSourceAfterCompletion)
                            .foregroundColor(.black)
                        .frame(width: 250, alignment: .leading)
                }
                // 按钮
                HStack {
                        Button(action: {
                        viewModel.cancelOperation()
                        }) {
                            Text("取消")
                                .foregroundColor(.black)
                                .frame(width: 60)
                                .padding(.vertical, 6)
                    }
                        .background(Color(NSColor(red: 0.925, green: 0.925, blue: 0.925, alpha: 1.0)))
                        .cornerRadius(6)
                        .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                        Button(action: {
                        viewModel.confirmCompression()
                        }) {
                            Text("确定")
                                .foregroundColor(.black)
                                .frame(width: 60)
                                .padding(.vertical, 6)
                        }
                        .background(Color(NSColor(red: 0.925, green: 0.925, blue: 0.925, alpha: 1.0)))
                        .cornerRadius(6)
                        .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.leading, 40)
                .padding(.trailing, 40)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding()
        .frame(width: 340)
        }
    }
}
