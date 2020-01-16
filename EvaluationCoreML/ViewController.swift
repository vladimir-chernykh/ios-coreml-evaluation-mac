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

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    @IBAction func folderSelectionButton(_ sender: Any) {
        
        let dialog = NSOpenPanel();

        dialog.title                   = "Choose a folder with images";
        dialog.showsResizeIndicator    = true;
        dialog.showsHiddenFiles        = false;
        dialog.allowsMultipleSelection = false;
        dialog.canChooseDirectories    = true;
        dialog.canChooseFiles          = false;
        
        if (dialog.runModal() ==  NSApplication.ModalResponse.OK) {
            
            let results = dialog.urls // Pathname of the directory

            do {
                let directoryContents = try FileManager.default.contentsOfDirectory(at: results[0], includingPropertiesForKeys: nil)

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
                    let filename = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("output.txt")
                    print(filename)
                    (predictions as NSArray).write(to: filename, atomically: true)
                    DispatchQueue.main.async {
                        self.predictionProgressLabel.title = "Done!"
                    }
                }
            } catch {
                print(error)
            }
        } else {
            print("Cancel")
            return
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
