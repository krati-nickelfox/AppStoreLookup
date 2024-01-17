//
//  AppStoreLookup.swift
//  Model
//
//  Created by Krati Mittal on 16/01/24.
//  Copyright © 2021 Nickelfox. All rights reserved.
//

import Foundation

public typealias AppStoreLookupHandler = (Result<AppStoreData, AppStoreLookupError>) -> Void

public enum UpdateType {
    case required
    case optional
    case unavailable
}

public enum AppStoreLookupError: Error {
    case networkError(Error)
    case invalidData
    case invalidURL
}

public struct AppStoreData {
    public let version: String
    public let releaseNotes: String
    public let artistId: String
    public let updateType: UpdateType
}

public class AppStoreLookup {
    
    struct AppStoreAPIConfig {
        static let appStoreLookup = "https://itunes.apple.com/lookup?bundleId="
    }

    struct AppInfo {
        private static let bundleDictionary = Bundle.main.infoDictionary
        
        public static var bundleIdentifier: String? {
            return (Self.bundleDictionary)?["CFBundleIdentifier"] as? String
        }
        
        public static var appVersion: String? {
            return (Self.bundleDictionary)?["CFBundleShortVersionString"] as? String
        }
    }
    
    private static func isStoreVersionNewer(_ currentVersion: String, _ storeVersion: String) -> Bool {
        return currentVersion.compare(storeVersion, options: .numeric) == .orderedAscending
    }

    private static func split(version: String) -> [Int] {
        return version.lazy.split { $0 == "." }.map { String($0) }.map { Int($0) ?? 0 }
    }

    private static func checkForUpdate(_ currentVersion: String, _ storeVersion: String) -> UpdateType {
        var oldVersion = Self.split(version: currentVersion)
        var newVersion = Self.split(version: storeVersion)

        if oldVersion.count > newVersion.count {
            for _ in 0..<oldVersion.count - newVersion.count {
                newVersion.append(0)
            }
        } else if newVersion.count > oldVersion.count {
            for _ in 0..<newVersion.count - oldVersion.count {
                oldVersion.append(0)
            }
        }

        let length = newVersion.count

        /* Checks for the type of version update in the format Major.Minor.Patch
            App update for patch releases is made optional
         */
        for index in 0..<length {
            let newVersionNum = newVersion[index]
            let oldVersionNum = oldVersion[index]
            if newVersionNum > oldVersionNum {
//                return index == length - 1 ? .optional : .required
                return .required
            }
        }

        return .unavailable
    }
    
    public static func lookupAppDataOnStore(completion: @escaping AppStoreLookupHandler) {
        guard let bundleId = AppInfo.bundleIdentifier,
              let url = URL(string: AppStoreAPIConfig.appStoreLookup + bundleId),
              let currentVersion = AppInfo.appVersion else {
            return completion(.failure(AppStoreLookupError.invalidURL))
        }

        let dataTask = URLSession.shared.dataTask(with: url) { (data, response, error) in
            do {
                if let error = error {
                    return completion(.failure(AppStoreLookupError.networkError(error)))
                }
                
                guard let jsonData = data,
                      let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
                      let results = (json["results"] as? [Any])?.first as? [String: Any],
                      let appstoreVersion = results["version"] as? String,
                      let appReleaseNotes = results["releaseNotes"] as? String,
                      let artistId = results["artistId"] as? Int,
                      !appstoreVersion.isEmpty
                else {
                    return completion(.failure(AppStoreLookupError.invalidData))
                }
                
                print("===== Data received from App Store data =====\n\(json)")
                let updateType = Self.checkForUpdate(currentVersion, appstoreVersion)
                let lookupData = AppStoreData(version: appstoreVersion,
                                              releaseNotes: appReleaseNotes,
                                              artistId: String(artistId),
                                              updateType: updateType)
                
                return completion(.success(lookupData))
            } catch {
                return completion(.failure(AppStoreLookupError.networkError(error)))
            }
        }
            
        dataTask.resume()
    }
}
