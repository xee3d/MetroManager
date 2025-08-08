
import SwiftUI

// MARK: - Add Project View
struct AddProjectView: View {
    @Environment(\.presentationMode) var presentationMode
    let metroManager: MetroManager
    
    @State private var projectName = ""
    @State private var projectPath = ""
    @State private var showingFolderPicker = false
    @State private var isPathValid = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("새 프로젝트 추가")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 20)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("프로젝트 이름")
                    .font(.headline)
                    .fontWeight(.medium)
                
                TextField("예: StoryLingo", text: $projectName)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("프로젝트 경로")
                    .font(.headline)
                    .fontWeight(.medium)
                
                HStack {
                    TextField("프로젝트 폴더 경로", text: $projectPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                        .onChange(of: projectPath) { newValue in
                            let isValid = metroManager.isValidProjectPath(path: newValue)
                            isPathValid = isValid
                            if !isValid && !newValue.isEmpty {
                                metroManager.errorMessage = "유효한 React Native 또는 Expo 프로젝트 경로가 아닙니다."
                                metroManager.showingErrorAlert = true
                            }
                        }
                    
                    Button("선택") {
                        showingFolderPicker = true
                    }
                    .buttonStyle(.bordered)
                    .font(.body)
                }
                
                if !projectPath.isEmpty && !isPathValid {
                    Text("유효한 React Native 또는 Expo 프로젝트 경로가 아닙니다.")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            HStack {
                Button("취소") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.bordered)
                .font(.body)
                
                Spacer()
                
                Button("추가") {
                    metroManager.addProject(name: projectName, path: projectPath)
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.bordered)
                .font(.body)
                .disabled(projectName.isEmpty || projectPath.isEmpty || !isPathValid)
            }
            .padding(.bottom, 20)
        }
        .padding()
        .frame(width: 400, height: 250)
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    projectPath = url.path
                    if projectName.isEmpty {
                        projectName = url.lastPathComponent
                    }
                    isPathValid = metroManager.isValidProjectPath(path: projectPath)
                }
            case .failure(let error):
                print("폴더 선택 오류: \(error)")
            }
        }
    }
}

struct AddProjectView_Previews: PreviewProvider {
    static var previews: some View {
        AddProjectView(metroManager: MetroManager())
    }
}
