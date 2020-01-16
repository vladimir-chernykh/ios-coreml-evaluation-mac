//
//  ViewController.swift
//  EvaluationCoreML
//
//  Created by Vladimir Chernykh on 16.01.2020.
//  Copyright © 2020 Vladimir Chernykh. All rights reserved.
//

import Cocoa
import Vision


// MARK: - User Interface
class ViewController: NSViewController {

    @IBOutlet weak var predictionProgressBar: NSProgressIndicator!
    @IBOutlet weak var predictionProgressLabel: NSTextFieldCell!

    var request: VNDetectFaceRectanglesRequest?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        request = VNDetectFaceRectanglesRequest()
        predictionProgressBar.minValue = 0
        predictionProgressBar.maxValue = 1
        predictionProgressBar.doubleValue = 0
    }
    
    @IBAction func folderSelectionButton(_ sender: Any) {
        
        let openDialog = NSOpenPanel();

        openDialog.title                   = "Choose a folder with images";
        openDialog.showsResizeIndicator    = true;
        openDialog.showsHiddenFiles        = false;
        openDialog.allowsMultipleSelection = false;
        openDialog.canChooseDirectories    = true;
        openDialog.canChooseFiles          = false;
        
        if (openDialog.runModal() ==  NSApplication.ModalResponse.OK) {

            let inputFolder = openDialog.url! // Pathname of the directory

            do {
                let directoryContents = try FileManager.default.contentsOfDirectory(at: inputFolder, includingPropertiesForKeys: nil)

                let jpgFiles = directoryContents.filter{ $0.pathExtension == "jpg" }

                predictionProgressBar.minValue = 0
                predictionProgressBar.maxValue = Double(jpgFiles.count)
                predictionProgressBar.doubleValue = 0
                predictionProgressLabel.title = "0/\(String(jpgFiles.count))"

                var predictions = [[String: Any]]()
                DispatchQueue.global().async {
                    for file in jpgFiles {
                        let pred = self.predict(with: file)
                        predictions.append(pred)
                        DispatchQueue.main.async {
                            self.predictionProgressBar.increment(by: 1.0)
                            self.predictionProgressLabel.title = "\(String(Int(self.predictionProgressBar.doubleValue)))/\(String(jpgFiles.count))"
                        }
                    }
                    DispatchQueue.main.async {
                        let saveDialog = NSSavePanel();
                        saveDialog.nameFieldStringValue = "output.plist"
                        if (saveDialog.runModal() ==  NSApplication.ModalResponse.OK) {
                            let savePath = saveDialog.url!
                            (predictions as NSArray).write(to: savePath, atomically: true)
                        }
                        self.predictionProgressLabel.title = "Done!"
                    }
                }
            } catch {
                print(error)
            }
        }

    }
    
}


// MARK: - Inference
extension ViewController {

    func predict(with url: URL) -> [String: Any] {
        guard let request = request else { fatalError() }

        // vision framework configures the input size of image following our model's input configuration automatically
        let handler = VNImageRequestHandler(url: url, options: [:])
        try? handler.perform([request])
        guard
          let results = request.results as? [VNFaceObservation]
          else {
            return ["file": url.absoluteString, "confidences": [Float](), "bboxes": [[Float]]()]
        }

        var bboxes = [[Float]]()
        var confidences = [Float]()
        for pred in results {
            let bbox = pred.boundingBox
            bboxes.append([Float(bbox.minX), Float(bbox.maxX), Float(bbox.minY), Float(bbox.maxY)])
            confidences.append(pred.confidence)
        }
        return ["file": url.absoluteString, "confidences": confidences, "bboxes": bboxes]
    }

}
