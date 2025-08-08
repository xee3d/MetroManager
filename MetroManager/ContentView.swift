import SwiftUI
import Foundation

// MARK: - Main View
struct ContentView: View {
    @StateObject private var metroManager = MetroManager()
    @State private var showingAddProject = false
    @State private var showingEditProject = false
    @State private var selectedProjectForEdit: MetroProject?
    
    var body: some View {
        HSplitView {
            // 프로젝트 목록
            VStack(alignment: .leading) {
                HStack {
                    Text("Metro 프로젝트")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: { metroManager.detectRunningMetroProcesses() }) {
                        Image(systemName: "magnifyingglass")
                            .font(.title3)
                    }
                    .help("실행 중인 Metro 프로세스 감지")
                    
                    Button(action: { metroManager.cleanupDeadProcesses() }) {
                        Image(systemName: "trash")
                            .font(.title3)
                    }
                    .help("죽은 외부 프로세스 정리")
                    
                    Button(action: { showingAddProject = true }) {
                        Image(systemName: "plus")
                            .font(.title3)
                    }
                    .help("새 프로젝트 추가")
                }
                .padding([.horizontal, .top])
                
                List(metroManager.projects, id: \.self, selection: $metroManager.selectedProject) { project in
                    ProjectRowView(project: project, metroManager: metroManager, showingEditProject: $showingEditProject, selectedProjectForEdit: $selectedProjectForEdit)
                }
                .listStyle(SidebarListStyle())
            }
            .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)
            
            // 콘솔 및 제어
            if let selectedProject = metroManager.selectedProject {
                ProjectDetailView(project: selectedProject, metroManager: metroManager)
            } else {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "sidebar.leading")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("왼쪽에서 프로젝트를 선택하세요")
                        .font(.title)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    Text("또는 + 버튼을 눌러 새 프로젝트를 추가하세요")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingAddProject) {
            AddProjectView(metroManager: metroManager)
        }
        .sheet(isPresented: $showingEditProject) {
            if let project = selectedProjectForEdit {
                EditProjectView(project: project, metroManager: metroManager)
            }
        }
        .alert(isPresented: $metroManager.showingErrorAlert) {
            Alert(
                title: Text("감지 결과"),
                message: Text(metroManager.errorMessage ?? "알 수 없는 메시지입니다."),
                dismissButton: .default(Text("확인")) {
                    metroManager.errorMessage = nil
                    metroManager.showingErrorAlert = false
                }
            )
        }
    }
}