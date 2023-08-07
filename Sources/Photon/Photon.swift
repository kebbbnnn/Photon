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

public enum DataSource {
    case server(URL)
    case local(URL)
}

public final class Photon : NSObject, URLSessionDataDelegate {
    public class func stream<Value: Hashable & Codable>(source: DataSource, streamBlock: @escaping (Set<Value>) -> Void, completionBlock: @escaping () -> Void) {
        switch source {
        case .server(let url):
            let manager = ServerSessionManager<Value>()
            manager.stream(url: url) {
                streamBlock($0)
            } completion: {
                completionBlock()
            }
        case .local(let _):
            // TODO: Support for local file streaming
            break
        }
    }
}

final class ServerSessionManager<Value: Hashable & Codable> : NSObject {
    
    private struct SessionCallback {
        let receive: (URLSession, URLSessionDataTask, Data) -> Void
        let complete: (URLSession, URLSessionTask, Error?) -> Void
    }
    
    private class SessionDataDelegate : NSObject, URLSessionDataDelegate {
        private var callback: SessionCallback
        
        init(callback: SessionCallback) {
            self.callback = callback
        }
        
        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            self.callback.receive(session, dataTask, data)
        }
        
        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            self.callback.complete(session, task, error)
        }
    }
    
    let decoder = IkigaJSONDecoder()
    
    private func decodeThenInsert(data: Data, to set: inout Set<Value>) {
        do {
            let values = try self.decoder.decode(Value.self, from: data)
            set.insert(values)
        } catch {
            debugPrint(error.localizedDescription)
        }
    }
    
    func stream(url: URL, received: @escaping (Set<Value>) -> Void, completion: @escaping () -> Void) {
        let semaphore = DispatchSemaphore(value: 1)
        
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        var previous: Data? = nil
        
        let callback = SessionCallback { session, dataTask, data in
            semaphore.wait()
            
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
                    if let previous_data = previous, lowerBound < 0 && upperBound < 0 { /// This means that this `}` is the first brace detected, so we find the `{` in the cached buffer.
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
                    } else if let previous_data = previous {
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
            
            received(set)
            
            previous = data
            
            semaphore.signal()
        } complete: { session, task, error in
            completion()
            previous = Data()
        }
        
        let delegate = SessionDataDelegate(callback: callback)
        
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: OperationQueue())
        
        let request = URLRequest(url: url)
        let task = session.dataTask(with: request)
        task.resume()
    }
    
}
