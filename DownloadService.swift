//
//  DownloadManager.swift
//  Stroyka
//
//  Created by Ilya Vinogradov on 11/1/17.
//  Copyright © 2017 Ilya Vinogradov. All rights reserved.
//

import Foundation
import Alamofire

typealias DownloadCompletion = ((_ filePath : String, _ error: Error?) -> Void)?
typealias ProgressHandler = ((Progress) -> Void)?

class DownloadService {
    
    static let shared = DownloadService()
    
    // кэш текущих загрузок.
    private var downloadsTasks : [String : [DownloadCompletion]]
    
    // загрузка файла по url в папка <app documents>/destinationPath, с именем файла fileName. По окончанию вызывается completion, с url сохраненного файла
    static func download(_ url: String, toPathInTemp destinationPath: String, fileName:String? = nil, progressCompletion: ProgressHandler, completion: DownloadCompletion) -> DownloadRequest?
    {
        let documentsURL = FileManager.default.temporaryDirectory
        
        // создать директорию если не существует
        let fileDirectory = documentsURL.appendingPathComponent(destinationPath)
        do {
            try FileManager.default.createDirectory(atPath: fileDirectory.path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print(error)
        }
        
        let fname = (fileName != nil) ? fileName! : url.lastPathComponent
        let fileURL = fileDirectory.appendingPathComponent(fname)
        let fileUrlPath = fileURL.path
        
        // уникальный id url'а
        let urlId = fileUrlPath.sha512Hex
        let isHaveTask = DownloadService.shared.downloadsTasks[urlId] != nil
        
        DownloadService.shared.addCompletion(completion, forKey: urlId)
        if (!isHaveTask) {
            let destination: DownloadRequest.DownloadFileDestination = { _, _ in
                return (fileURL, [.removePreviousFile])
            }
            return Alamofire.download(url, to: destination).downloadProgress(closure: { (progress) in
                progressCompletion?(progress)
            }).response {[urlId, fileUrlPath] (response) in
                var fUrl : String? = fileUrlPath
                if (response.error != nil) {
                    fUrl = ""
                }
                let completions = DownloadService.shared.downloadsTasks[urlId]
                completions?.forEach {$0?(fUrl!, response.error)}
                
                DownloadService.shared.downloadsTasks[urlId] = nil
            }
        }
        return nil
    }
    
    init() {
        downloadsTasks = [:]
    }
    
    func addCompletion(_ completion:DownloadCompletion, forKey: String) {
        if (downloadsTasks[forKey] == nil) {
            downloadsTasks[forKey] = [ completion ]
        } else {
            downloadsTasks[forKey]?.append(completion)
        }
    }
}
