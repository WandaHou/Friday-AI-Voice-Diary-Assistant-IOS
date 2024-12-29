import UIKit

class TranscriptListViewController: UITableViewController {
    private var viewModel: TranscriptListViewModel
    
    init(viewModel: TranscriptListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
        viewModel.onViewDidLoad()
    }
    
    private func setupUI() {
        title = "Transcripts"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "TranscriptCell")
        
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(refreshTranscripts), for: .valueChanged)
    }
    
    private func setupBindings() {
        viewModel.onRecordingsUpdated = { [weak self] in
            self?.tableView.reloadData()
            self?.refreshControl?.endRefreshing()
        }
    }
    
    @objc private func refreshTranscripts() {
        Task { await viewModel.loadTranscripts() }
    }
    
    // MARK: - Table View Data Source
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.recordings.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TranscriptCell", for: indexPath)
        let recording = viewModel.recordings[indexPath.row]
        
        cell.textLabel?.text = viewModel.getDisplayTitle(for: recording.audio)
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
    
//    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        tableView.deselectRow(at: indexPath, animated: true)
//        let recording = viewModel.recordings[indexPath.row]
//        showTranscript(for: recording.audio)
//    }
//    
//    private func showTranscript(for recordingURL: URL) {
//        Task {
//            if let transcript = await viewModel.getTranscript(for: recordingURL) {
//                let detailViewModel = TranscriptDetailViewModelImpl(
//                    transcript: transcript,
//                    date: viewModel.getDisplayTitle(for: recordingURL)
//                )
//                let detailVC = TranscriptDetailViewController(viewModel: detailViewModel)
//                navigationController?.pushViewController(detailVC, animated: true)
//            }
//        }
//    }
}
