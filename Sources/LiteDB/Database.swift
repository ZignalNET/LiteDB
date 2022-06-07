//
//  Database.swift
//  Part of LiteDB. A thin IOS Swift wrapper around Sqlite3 database
//  Created by Emmanuel Adigun on 2022/05/24. emmanuel@zignal.net
//  Copyright © 2022. All rights reserved.

import Foundation
import SQLite3

open class Database: NSObject {
    private var fileName: String?
    private var fullFilePath: String?
    private var fileHandle: OpaquePointer?
    private let dispatchQueue = DispatchQueue(label:"queue.litedb.zignal.net", attributes:[])
    
    private static let _sharedInstance = Database()
    public static func sharedInstance(_ dbName: String) -> Database {
        _sharedInstance.fileName = dbName
        do { try _sharedInstance.open() } catch { }
        return _sharedInstance as! Self
    }
    
    
    public static var databaseDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.locale = Locale.current 
        return formatter
    }()
    
    private override init() {
        super.init()
    }
    
    deinit {
        do { try close() } catch {}
    }
    
    private func datafilePath(_ dbName: String ) -> String? {
        var filepath: String?
        do {
            let databaseURL = try FileManager.default
                .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent(dbName)
            filepath = databaseURL.absoluteString
        }
        catch(let error) {
            print("Error fetching database URL : ", error)
            filepath = nil
        }
        return filepath
    }
    
    private func open() throws {
        try close()
        guard let fileName = fileName, let filepath = datafilePath(fileName) else { return  }
        let error = sqlite3_open_v2(filepath,&fileHandle,(SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE),nil)
        if error != SQLITE_OK {
            throw DatabaseError.openFailed(error, "Failed to open DB!")
        }
        fullFilePath = filepath
        NSLog("Database => \(fileName) successfully opened!")
    }
    
    private func lastErrorMessage() -> String{
        if fileHandle == nil { return "" }
        return String(cString: sqlite3_errmsg(fileHandle))
    }
    
    private func prepare(_ sql: String, _ parameters: QueryParameters?) throws -> Statement? {
        var statement: Statement?
        guard fileHandle != nil else { throw DatabaseError.databaseNotOpened("Database not opened") }
        let result = sqlite3_prepare_v2(fileHandle, sql, -1, &statement, nil)
        if result != SQLITE_OK {
            sqlite3_finalize(statement)
            throw DatabaseError.unableToPrepareStatement(result, "Unable to prepare statement: \(sql), \(lastErrorMessage())")
        }
        
        if let parameters = parameters {
            let parameterCount = parameters.count
            let resultCount    = sqlite3_bind_parameter_count(statement)
            if parameterCount != resultCount {
                throw DatabaseError.unableToPrepareStatement(resultCount, "Unable to prepare statement: Mismatched parameters \(sql), parameters: \(parameters)")
            }
            if let statement = statement {
                var result: Int32 = 0
                for (i, parameter) in parameters.enumerated() {
                    result = parameter.bind(to: statement, atIndex: Int32(i+1))
                    if result != SQLITE_OK {
                        result = sqlite3_bind_null(statement, Int32(i+1))
                        //if all else fails ..
                        if result != SQLITE_OK {
                            sqlite3_finalize(statement)
                            throw DatabaseError.unableToBindParameter(result, "Unable to bind parameter to sql: \(sql), parameter: \(parameter) at index \(i), Error : \(lastErrorMessage())")
                        }
                    }
                }
            }
        }
        return statement
    }
    
    private func getColumnType(fromStatement: Statement, atIndex: Int32 ) -> Int32 {
        guard let buffer = sqlite3_column_decltype(fromStatement, atIndex) else {
            return sqlite3_column_type(fromStatement, atIndex)
        }
        guard let type = ColumnType(rawValue: String(validatingUTF8: buffer)!.uppercased())?.type else { return SQLITE_NULL }
        return type
    }
    
    private func getColumnValue(atIndex: Int32, fromStatement: Statement, type: Int32) -> Any?{
        //Todo .. make this function to be generic by using templates
        if type      == SQLITE_FLOAT { return Double(from: fromStatement, atIndex: atIndex) }
        else if type == SQLITE_INTEGER { return Int32(from: fromStatement, atIndex: atIndex) }
        else if type == SQLITE_DATE { return Date(from: fromStatement, atIndex: atIndex) }
        else if type == SQLITE_DATETIME { return Date(from: fromStatement, atIndex: atIndex) }
        else if type == SQLITE_TEXT { return String(from: fromStatement, atIndex: atIndex) }
        else if type == SQLITE_BLOB { return Data(from: fromStatement, atIndex: atIndex) }
        return String(from: fromStatement, atIndex: atIndex) // defaults ...
    }
    
    public func totalRows(sql: String?) throws -> Int32 {
        guard fileHandle != nil else { throw DatabaseError.databaseNotOpened("Database not opened") }
        guard let sql = sql else { throw DatabaseError.invalidQuery("SQL is nil")}
        var count: Int32 = 0
        try dispatchQueue.sync {
            do {
                let statement = try prepare(sql, nil)
                let result = sqlite3_step(statement)
                if ( result == SQLITE_ROW ) {
                    count = sqlite3_column_int(statement, 0)
                    sqlite3_finalize(statement)
                }
                else {
                    sqlite3_finalize(statement)
                    throw DatabaseError.unableToExecuteQuery(result, "Error: \(sql)")
                }
            }
            catch( let error ) {
                throw error
            }
        }
        return count
    }
    
    open func close() throws {
        if fileHandle == nil { return }
        let result = sqlite3_close(fileHandle)
        if result != SQLITE_OK { fileHandle = nil;  throw DatabaseError.closeFailed(result, "Unable to close database") }
        fileHandle = nil
    }
    
    open func remove() throws {
        if let filePath = fileName, let cpath = datafilePath(filePath) {
            let tpath = cpath.replacingOccurrences(of: "file://", with: "")
            do {
                if FileManager.default.fileExists(atPath: tpath) {
                    try FileManager.default.removeItem(atPath: tpath)
                    NSLog("File ==>> \(filePath) removed ...")
                    self.fileName   = nil
                }
            }
            catch(let error) {
                throw DatabaseError.removeFailed("Error removing database from URL: \(error)")
            }
                
        }
    }
    
    open func isOpen() -> Bool {
        return self.fileHandle != nil
    }
    
    open func execute(_ sql: String, _ parameters: QueryParameters?, _ callback: RowQueryResults?) throws {
        var statement: Statement?
        try dispatchQueue.sync {
            do {
                statement = try prepare(sql, parameters)
                let result = sqlite3_step(statement)
                if ![SQLITE_OK, SQLITE_DONE].contains(result) {
                    sqlite3_finalize(statement)
                    throw DatabaseError.unableToExecuteQuery(result, "Unable to execute sql: \(sql), Error : \(lastErrorMessage())")
                }
                sqlite3_finalize(statement)
                callback?(nil, (result, sqlite3_last_insert_rowid(self.fileHandle),sqlite3_changes(self.fileHandle),sql), nil)
            }
            catch( let error ) {
                //sqlite3_finalize(statement)
                throw error
            }
        }
    }
    
    open func query(_ sql: String, _ parameters: QueryParameters?, _ callback: RowQueryResults?) throws -> TableRows {
        var statement: Statement?
        var rows        = TableRows()
        try dispatchQueue.sync {
            do {
                var firstRow = false
                statement = try prepare(sql, parameters)
                var columnNames = ColumnNames()
                var columnTypes = ColumnTypes()
                let columnCount = sqlite3_column_count(statement)
                var result = sqlite3_step(statement)
                while result == SQLITE_ROW {
                    if !firstRow {
                        for idx in 0..<columnCount {
                            columnNames.append(String(validatingUTF8:sqlite3_column_name(statement, idx)!)!)
                            columnTypes.append(self.getColumnType(fromStatement: statement!, atIndex: idx))
                        }
                        firstRow = true
                    }
                    
                    var row = TableRow()
                    for idx in 0..<columnCount {
                        let name = columnNames[Int(idx)]
                        let type = columnTypes[Int(idx)]
                        row[name] = self.getColumnValue(atIndex: idx, fromStatement: statement!, type: type )
                    }
                    rows.append(row)
                    // Fetch Next row
                    result = sqlite3_step(statement)
                }
                
                sqlite3_finalize(statement)
                callback?(rows, (result, sqlite3_last_insert_rowid(self.fileHandle),sqlite3_changes(self.fileHandle),sql), nil)
            }
            catch (let error) {
                //sqlite3_finalize(statement)
                throw error
            }
        }
        
        return rows
    }
    
    open func query<T: TableRowObject>(_ sql: String, _ parameters: QueryParameters?, _ callBack: RowCallback<T>?) throws  {
        var statement: Statement?
        try dispatchQueue.sync {
            do {
                var firstRow = false
                statement = try prepare(sql, parameters)
                var columnNames = ColumnNames()
                var columnTypes = ColumnTypes()
                let columnCount = sqlite3_column_count(statement)
                var result = sqlite3_step(statement)
                while result == SQLITE_ROW {
                    if !firstRow {
                        for idx in 0..<columnCount {
                            columnNames.append(String(validatingUTF8:sqlite3_column_name(statement, idx)!)!)
                            columnTypes.append(self.getColumnType(fromStatement: statement!, atIndex: idx))
                        }
                        firstRow = true
                    }
                    
                    let t = T.init()
                    for idx in 0..<columnCount {
                        let name = columnNames[Int(idx)]
                        let type = columnTypes[Int(idx)]
                        if let value = self.getColumnValue(atIndex: idx, fromStatement: statement!, type: type ){
                            print( name, value, getObjectProperties(t: t) )
                            //t.setValue(value, forKey: name)
                            t.setValue(value, forUndefinedKey: name)
                        }
                    }
                    callBack?(t as T)
                    
                    // Fetch Next row
                    result = sqlite3_step(statement)
                }
                
                sqlite3_finalize(statement)
            }
            catch (let error) {
                //sqlite3_finalize(statement)
                throw error
            }
        }
    }
    
}

//This is NOT Called; needs to be fixed !!!!
extension Database {
    /*for (_, attr) in Mirror(reflecting:self).children.enumerated() {
    if let name = attr.label, let column = attr.value as? Column {
        columns[name] = column
    }
}
    */
    private func getObjectProperties<T>(t: T) {
        var columns: Dictionary<String,Any> = [:]
        for (_, attr) in Mirror(reflecting:t).children.enumerated() {
            if let name = attr.label {
                let value = attr.value
                columns[name] = value
            }
        }
    }
}

