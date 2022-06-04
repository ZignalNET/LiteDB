//
//  Errors.swift
//  Part of LiteDB. A thin IOS Swift wrapper around Sqlite3 database
//  Created by Emmanuel Adigun on 2022/05/24. emmanuel@zignal.net
//  Copyright © 2022. All rights reserved.
//

import Foundation

enum DatabaseError: Error {
    case openFailed(Int32, String)
    case closeFailed(Int32, String)
    case removeFailed(String)
    case invalidHandle(String)
    case invalidQuery(String)
    case databaseNotOpened(String)
    case unableToPrepareStatement(Int32, String)
    case unableToBindParameter(Int32, String)
    case unableToExecuteQuery(Int32, String)
    case noPrimaryKey(String)
}
