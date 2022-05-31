//
//  Errors.swift
//  balance
//
//  Created by Emmanuel Adigun on 2022/05/25.
//  Copyright © 2022 Zignal Systems. All rights reserved.
//

import Foundation

enum DatabaseError: Error {
    case openFailed(Int32, String)
    case closeFailed(Int32, String)
    case removeFailed(String)
    case invalidHandle(String)
    case databaseNotOpened(String)
    case unableToPrepareStatement(Int32, String)
    case unableToBindParameter(Int32, String)
    case unableToExecuteQuery(Int32, String)
    case noPrimaryKey(String)
}
