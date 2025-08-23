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
            VStack(alignment: .leading, spacing: 8) {
                // 제목만 단독 라인
                HStack {
                    Text("Metro 프로젝트")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer()
                }
                .padding([.horizontal, .top])

                // 도구 라인 (별도 줄)
                HStack(spacing: 12) {
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
                    Button(action: { 
                        metroManager.stopAllMetroServers()
                    }) {
                        Image(systemName: "stop.circle.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                    }
                    .help("전체 Metro 서버 종료")
                    Button(action: { showingAddProject = true }) {
                        Image(systemName: "plus")
                            .font(.title3)
                    }
                    .help("새 프로젝트 추가")
                }
                .padding(.horizontal)
                
                List(displayedProjects, id: \.self, selection: $metroManager.selectedProject) { project in
                    ProjectRowView(project: project, metroManager: metroManager, showingEditProject: $showingEditProject, selectedProjectForEdit: $selectedProjectForEdit)
                }
                .listStyle(SidebarListStyle())

                // 하단 아이콘 토글 (라벨 없이 깔끔하게)
                HStack(spacing: 14) {
                    Button(action: {
                        metroManager.hideDuplicatePorts.toggle()
                        metroManager.saveOptions()
                    }) {
                        Image(systemName: metroManager.hideDuplicatePorts ? "rectangle.stack.fill" : "rectangle.stack")
                            .symbolRenderingMode(.monochrome)
                            .foregroundColor(metroManager.hideDuplicatePorts ? .green : .secondary)
                    }
                    .help("중복 숨기기")

                    Button(action: {
                        metroManager.autoAddExternalProcesses.toggle()
                        metroManager.saveOptions()
                    }) {
                        Image(systemName: metroManager.autoAddExternalProcesses ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                            .symbolRenderingMode(.monochrome)
                            .foregroundColor(metroManager.autoAddExternalProcesses ? .green : .secondary)
                    }
                    .help("외부 자동추가")

                    Spacer()
                }
                .padding([.horizontal, .bottom])
                .controlSize(.small)
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
    private var displayedProjects: [MetroProject] {
        // 동일 포트 중복 제거: 실행 중 내부 프로세스 우선, 다음은 경로가 알려진 외부 프로세스
        var result: [MetroProject] = []
        let source = metroManager.projects
        if !metroManager.hideDuplicatePorts {
            return source.sorted { lhs, rhs in
                if lhs.port == rhs.port { return lhs.name < rhs.name }
                return lhs.port < rhs.port
            }
        }
        let grouped = Dictionary(grouping: source, by: { $0.port })
        for (_, group) in grouped {
            // 우선순위: 내부 실행중 > 내부 중지 > 외부 실행중 > 외부 중지
            if let pick = group.first(where: { !$0.isExternalProcess && $0.isRunning })
                ?? group.first(where: { !$0.isExternalProcess })
                ?? group.first(where: { $0.isExternalProcess && $0.isRunning })
                ?? group.first {
                result.append(pick)
            }
        }
        // 포트 오름차순, 이름 정렬
        return result.sorted { lhs, rhs in
            if lhs.port == rhs.port { return lhs.name < rhs.name }
            return lhs.port < rhs.port
        }
    }
}