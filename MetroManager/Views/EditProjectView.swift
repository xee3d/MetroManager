
import SwiftUI

// MARK: - Edit Project View
struct EditProjectView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var project: MetroProject
    let metroManager: MetroManager
    
    @State private var projectName: String
    @State private var projectPath: String
    @State private var projectPort: Int
    @State private var projectType: ProjectType
    @State private var showingFolderPicker = false
    
    init(project: MetroProject, metroManager: MetroManager) {
        self.project = project
        self.metroManager = metroManager
        _projectName = State(initialValue: project.name)
        _projectPath = State(initialValue: project.path)
        _projectPort = State(initialValue: project.port)
        _projectType = State(initialValue: project.projectType)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("프로젝트 편집")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("프로젝트 이름")
                    .font(.headline)
                
                TextField("예: StoryLingo", text: $projectName)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("프로젝트 경로")
                    .font(.headline)
                
                HStack {
                    TextField("프로젝트 폴더 경로", text: $projectPath)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("선택") {
                        showingFolderPicker = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("포트")
                    .font(.headline)
                
                TextField("예: 8081", value: $projectPort, formatter: NumberFormatter())
                    .textFieldStyle(.roundedBorder)
                    
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("프로젝트 타입")
                    .font(.headline)
                
                Picker("프로젝트 타입", selection: $projectType) {
                    ForEach(ProjectType.allCases, id: \.self) { type in
                        Text(type.description).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            HStack {
                Button("취소") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("저장") {
                    metroManager.editProject(project: project, newName: projectName, newPath: projectPath, newPort: projectPort, newType: projectType)
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.bordered)
                .disabled(projectName.isEmpty || projectPath.isEmpty || projectPort == 0)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .frame(width: 450, height: 380)
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    projectPath = url.path
                }
            case .failure(let error):
                print("폴더 선택 오류: \(error)")
            }
        }
    }
}

struct EditProjectView_Previews: PreviewProvider {
    static var previewMetroManager: MetroManager = {
        let manager = MetroManager()
        manager.addProject(name: "Sample Project", path: "/Users/user/Projects/SampleProject")
        return manager
    }()

    static var previewProject: MetroProject = {
        let project = previewMetroManager.projects[0]
        project.name = "Existing Project"
        project.path = "/Users/user/Projects/ExistingProject"
        project.port = 8081
        return project
    }()

    static var previews: some View {
        EditProjectView(project: previewProject, metroManager: previewMetroManager)
            .previewDisplayName("Edit Project")
            .frame(width: 450, height: 380)
    }
}
