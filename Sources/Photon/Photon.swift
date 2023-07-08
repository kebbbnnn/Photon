//
//  Photon.swift
//  Photon
//
//  Created by Kevin Ladan on 7/9/23.
//

import Foundation
import IkigaJSON
import Dispatch
import ObjectiveC

public class Photon<Value: Hashable & Codable> : NSObject, URLSessionDataDelegate {
    
    private var session: URLSession! = nil
    private var decoder = IkigaJSONDecoder()
    private var previous: [URL: Data] = [:]
    private let semaphore = DispatchSemaphore(value: 1)

    public override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())
    }
    
    private var tasks: [URL: URLSessionDataTask] = [:]
    private var streamBlocks: [URL: (Set<Value>) -> Void] = [:]
    private var completionBlocks: [URL: () -> Void] = [:]

    public func stream(for url: URL, streamBlock: @escaping (Set<Value>) -> Void, completionBlock: @escaping () -> Void) {
        guard !self.streamBlocks.contains(where: { $0.key == url }) else { return }
        
        self.streamBlocks[url] = streamBlock
        self.completionBlocks[url] = completionBlock

        let request = URLRequest(url: url)
        let task = self.session.dataTask(with: request)
        self.tasks[url] = task
        task.resume()
    }

    public func stop() {
        self.tasks.forEach { $0.value.cancel() }
        self.semaphore.wait()
        self.previous = [:]
        self.semaphore.signal()
    }
    
    private func decodeThenInsert(data: Data, to set: inout Set<Value>) {
        do {
            let values = try self.decoder.decode(Value.self, from: data)
            set.insert(values)
        } catch {
            debugPrint(error.localizedDescription)
        }
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let request = dataTask.currentRequest, let url = request.url else { return }
        
        self.semaphore.wait()
        
        var lowerBound: Int = -1
        var upperBound: Int = -1
        var inside: Bool = true
        
        var set = Set<Value>()
        
        for index in 0 ..< data.count {
            let byte = data[index]
            
            switch byte {
            case 123: /// ASCII value for `{`
                lowerBound = index
                
            case 125: /// ASCII value for `}`
                if let previous_data = self.previous[url], lowerBound < 0 && upperBound < 0 { /// This means that this `}` is the first brace detected, so we find the `{` in the cached buffer.
                    var buffer_index = previous_data.count - 1
                    
                    while buffer_index >= 0 {
                        let byte = previous_data[buffer_index]
                        
                        if 123 == byte { /// ASCII value for `{`
                            lowerBound = buffer_index
                            inside = false
                            break
                        }
                        buffer_index -= 1
                    }
                }
                
                upperBound = index
                
            default: break
            }
            
            if lowerBound != -1 && upperBound != -1 {
                if inside {
                    if lowerBound < upperBound {
                        let data = data[lowerBound...upperBound]
                        self.decodeThenInsert(data: data, to: &set)
                    }
                } else if let previous_data = self.previous[url] {
                    let buffer_count = previous_data.count
                    if lowerBound < buffer_count {
                        let data = previous_data[lowerBound..<buffer_count] + data[0...upperBound]
                        self.decodeThenInsert(data: data, to: &set)
                    }
                }
                
                lowerBound = -1
                upperBound = -1
                inside = true
            }
        }
        
        self.received(chunk: set, for: url)
        
        self.previous[url] = data
        
        self.semaphore.signal()
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let request = task.currentRequest, let url = request.url else { return }
        
        self.completionBlocks[url]?()
        self.cleanup(url)
    }
    
    func received(chunk values: Set<Value>, for url: URL) {
        guard !values.isEmpty else { return }
        
        self.streamBlocks[url]?(values)
    }
    
    private func cleanup(_ url: URL) {
        self.previous[url] = Data()
        
        self.tasks.removeValue(forKey: url)
        self.streamBlocks.removeValue(forKey: url)
        self.completionBlocks.removeValue(forKey: url)
    }
}
