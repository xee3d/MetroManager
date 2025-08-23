
import SwiftUI
import Foundation

// MARK: - Project Row View
struct ProjectRowView: View {
    // For SwiftUI Previews
    static var previewMetroManager: MetroManager = {
        let manager = MetroManager()
        manager.addProject(name: "Sample Project 1", path: "/Users/user/Projects/SampleProject1")
        manager.addProject(name: "Sample Project 2", path: "/Users/user/Projects/SampleProject2")
        return manager
    }()

    static var previewProject: MetroProject = {
        let project = previewMetroManager.projects[0]
        project.status = .running
        project.isRunning = true
        project.addInfoLog("Sample log line 1")
        project.addInfoLog("Sample log line 2")
        return project
    }()

    static var previewProjectStopped: MetroProject = {
        let project = previewMetroManager.projects[1]
        project.status = .stopped
        project.isRunning = false
        return project
    }()

    @ObservedObject var project: MetroProject
    let metroManager: MetroManager
    
    @Binding var showingEditProject: Bool
    @Binding var selectedProjectForEdit: MetroProject?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(project.name)
                        .font(.title3)
                        .fontWeight(.medium)
                    
                    // 프로젝트 타입 표시 (클릭 가능)
                    Button(action: {
                        // 프로젝트 타입 토글
                        let newType: ProjectType = project.projectType == .expo ? .reactNativeCLI : .expo
                        metroManager.updateProjectType(for: project, to: newType)
                    }) {
                        Text(project.projectType.rawValue)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(project.projectType == .expo ? Color.blue.opacity(0.2) : Color.orange.opacity(0.2))
                            .foregroundColor(project.projectType == .expo ? .blue : .orange)
                            .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("클릭하여 프로젝트 타입 변경 (Expo ↔ React Native CLI)")
                    
                    // 외부 프로세스 표시
                    if project.isExternalProcess {
                        Text("외부")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.2))
                            .foregroundColor(.purple)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                }
                
                Text("포트: \(project.port)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(project.path)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Capsule()
                    .fill(project.status.color)
                    .frame(width: 8, height: 8)
                Text(project.status.text)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(project.status.color)
            }
        }
        .padding(.vertical, 8)
        .contextMenu {
            Button("편집") {
                metroManager.selectedProject = project // Select the project for detail view
                showingEditProject = true
                selectedProjectForEdit = project
            }
            Button("삭제") {
                metroManager.removeProject(project)
            }
        }
    }
}

struct ProjectRowView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ProjectRowView(project: ProjectRowView.previewProject, metroManager: ProjectRowView.previewMetroManager, showingEditProject: .constant(false), selectedProjectForEdit: .constant(nil))
                .previewDisplayName("Running Project")

            ProjectRowView(project: ProjectRowView.previewProjectStopped, metroManager: ProjectRowView.previewMetroManager, showingEditProject: .constant(false), selectedProjectForEdit: .constant(nil))
                .previewDisplayName("Stopped Project")
        }
        .previewLayout(.fixed(width: 300, height: 60))
    }
}
