import Cocoa

class ViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var addButton: NSButton!
    @IBOutlet weak var removeButton: NSButton!
    @IBOutlet weak var modePopUp: NSPopUpButton!
    @IBOutlet weak var levelPopUp: NSPopUpButton!
    @IBOutlet weak var processButton: NSButton!
    @IBOutlet weak var progressBar: NSProgressIndicator!
    @IBOutlet weak var clearButton: NSButton!
    @IBOutlet weak var selectAllButton: NSButton!
    
    var files: [MACFile] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        setupControls()
        tableView.allowsMultipleSelection = true
    }
    
    func setupControls() {
        modePopUp.removeAllItems()
        modePopUp.addItems(withTitles: ["Compress", "Decompress", "Verify", "Convert", "Make APL"])
        modePopUp.selectItem(at: 0)
        modePopUp.target = self
        modePopUp.action = #selector(modeChanged(_:))
        
        levelPopUp.removeAllItems()
        levelPopUp.addItems(withTitles: ["Fast", "Normal", "High", "Extra High", "Insane"])
        levelPopUp.selectItem(at: 1)
    }
    
    @objc func modeChanged(_ sender: Any) {
        let mode = modePopUp.indexOfSelectedItem
        levelPopUp.isEnabled = (mode == 0 || mode == 3)
    }
    
    @IBAction func addFiles(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedFileTypes = ["wav", "aiff", "aif", "w64", "snd", "au", "caf", "rf64", "bw64", "ape", "mac", "apl", "flac", "cue"]
        
        panel.begin { response in
            if response == .OK {
                for url in panel.urls {
                    self.files.append(MACFile(url: url))
                }
                self.tableView.reloadData()
            }
        }
    }
    
    @IBAction func removeFiles(_ sender: Any) {
        let selected = tableView.selectedRowIndexes.reversed()
        for index in selected {
            files.remove(at: index)
        }
        tableView.reloadData()
    }
    
    @IBAction func clearFiles(_ sender: Any) {
        files.removeAll()
        tableView.reloadData()
    }
    
    @IBAction func selectAll(_ sender: Any) {
        tableView.selectAll(sender)
    }
    
    @IBAction func processFiles(_ sender: Any) {
        let mode = modePopUp.indexOfSelectedItem
        let level = levelPopUp.indexOfSelectedItem
        
        processButton.isEnabled = false
        progressBar.isHidden = false
        progressBar.startAnimation(nil)
        
        DispatchQueue.global().async {
            let processor = MACProcessor()
            for file in self.files {
                processor.process(file: file, mode: mode, level: level)
            }
            DispatchQueue.main.async {
                self.processButton.isEnabled = true
                self.progressBar.stopAnimation(nil)
                self.progressBar.isHidden = true
                self.tableView.reloadData()
            }
        }
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return files.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let file = files[row]
        let identifier = tableColumn?.identifier.rawValue ?? ""
        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(identifier), owner: self) as? NSTableCellView
        
        if identifier == "NameColumn" {
            cell?.textField?.stringValue = file.name
        } else if identifier == "StatusColumn" {
            cell?.textField?.stringValue = file.status
        } else if identifier == "SizeColumn" {
            cell?.textField?.stringValue = file.sizeString
        } else if identifier == "TypeColumn" {
            cell?.textField?.stringValue = file.type
        }
        return cell
    }
}

class MACFile {
    var url: URL
    var name: String
    var status: String = "Ready"
    var sizeString: String = ""
    var type: String = ""
    
    init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
        self.type = url.pathExtension.uppercased()
        do {
            let resources = try url.resourceValues(forKeys: [.fileSizeKey])
            if let size = resources.fileSize {
                let formatter = ByteCountFormatter()
                self.sizeString = formatter.string(fromByteCount: Int64(size))
            }
        } catch {
            self.sizeString = "Unknown"
        }
    }
}
