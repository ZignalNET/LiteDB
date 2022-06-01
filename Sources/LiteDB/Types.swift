//
//  Types.swift
//  Part of LiteDB. A thin IOS Swift wrapper around Sqlite3 database
//  Created by Emmanuel Adigun on 2022/05/24. emmanuel@zignal.net
//  Copyright © 2022 Zignal Systems. All rights reserved.
//

import Foundation
import SQLite3

public let SQLITE_DATE            = SQLITE_NULL + 1
public let SQLITE_DATETIME        = SQLITE_DATE + 1

private let SQLITE_STATIC          = unsafeBitCast(0, to:sqlite3_destructor_type.self)
private let SQLITE_TRANSIENT       = unsafeBitCast(-1, to:sqlite3_destructor_type.self)

public typealias TableRow          = Dictionary<String, Any?>
public typealias TableRows         = [TableRow]

public typealias ColumnNames       = [String]
public typealias ColumnTypes       = [Int32]

public typealias Statement         = OpaquePointer
public typealias QueryParameters   = [Parameter]

public typealias ExecuteResults    = (result: Int32?, lastInsertedRowId: Int64?, totalRowsAffected: Int32?, sql: String?)
public typealias RowQueryResults   = (_ rows: TableRows?, _ stats: ExecuteResults? , _ error: Error?) -> Void
public typealias RowCallback<T>    = (_ row: T ) -> Void

public typealias DateTime          = Date
typealias        TableColumns      = Dictionary<String, Column>

public protocol Parameter {
    init?(from statement: Statement, atIndex: Int32)
    func bind(to statement: Statement, atIndex: Int32) -> Int32
}

extension String: Parameter {
    public init?(from statement: Statement, atIndex: Int32) {
        guard let c = sqlite3_column_text(statement, atIndex) else { return nil }
        self = String(cString: c)
    }
    public func bind(to statement: Statement, atIndex: Int32) -> Int32 {
        return sqlite3_bind_text(statement, atIndex, cString(using: .utf8), -1, SQLITE_TRANSIENT)
    }
}

extension Data: Parameter {
    public init?(from statement: Statement, atIndex: Int32) {
        let size = sqlite3_column_bytes(statement, atIndex)
        guard let data = sqlite3_column_blob(statement, atIndex) else { return nil }
        self = Data(bytes: data, count: Int(size))
    }
    public func bind(to statement: Statement, atIndex: Int32) -> Int32 {
        return withUnsafeBytes { pointer in
            let bytes = pointer.baseAddress
            return sqlite3_bind_blob(statement, atIndex, bytes, Int32(count), SQLITE_TRANSIENT)
        }
    }
}

extension Date: Parameter {
    public init?(from statement: Statement, atIndex: Int32) {
        guard let str = String(from: statement, atIndex: atIndex) else { return nil }
        guard let date = Database.databaseDateFormatter.date(from: str) else { return nil }
        self = date
    }
    public func bind(to statement: Statement, atIndex: Int32) -> Int32 {
        let str = Database.databaseDateFormatter.string(from: self)
        return sqlite3_bind_text(statement, atIndex, str.cString(using: .utf8), -1, SQLITE_TRANSIENT)
    }
}

extension Int: Parameter {
    public init?(from statement: Statement, atIndex: Int32) {
        self = Int(sqlite3_column_int(statement,atIndex))
    }
    public func bind(to statement: Statement, atIndex: Int32) -> Int32 {
        return sqlite3_bind_int(statement, atIndex, Int32(self))
    }
}

extension Int32: Parameter {
    public init?(from statement: Statement, atIndex: Int32) {
        self = Int32(sqlite3_column_int(statement,atIndex))
    }
    public func bind(to statement: Statement, atIndex: Int32) -> Int32 {
        return sqlite3_bind_int(statement, atIndex, Int32(self))
    }
}

extension Int64: Parameter {
    public init?(from statement: Statement, atIndex: Int32) {
        self = Int64(sqlite3_column_int64(statement,atIndex))
    }
    public func bind(to statement: Statement, atIndex: Int32) -> Int32 {
        return sqlite3_bind_int64(statement, atIndex, Int64(self))
    }
}

extension Bool: Parameter {
    public init?(from statement: Statement, atIndex: Int32) {
        self = Bool( Int(sqlite3_column_int(statement,atIndex)) > 0 ? true : false )
    }
    public func bind(to statement: Statement, atIndex: Int32) -> Int32 {
        let num: Int32 = self ? 1 : 0
        return sqlite3_bind_int(statement, atIndex, num)
    }
}

extension Double: Parameter {
    public init?(from statement: Statement, atIndex: Int32) {
        guard let decimal = Decimal(from: statement, atIndex: atIndex) else { return nil }
        self = NSDecimalNumber(decimal:decimal).doubleValue
    }
    public func bind(to statement: Statement, atIndex: Int32) -> Int32 {
        return sqlite3_bind_double(statement, atIndex, self)
    }
}

extension Decimal: Parameter {
    public init?(from statement: Statement, atIndex: Int32) {
        guard let str = String(from: statement, atIndex: atIndex) else { return nil }
        guard let value = Decimal(string: str, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        self = value
    }
    public func bind(to statement: Statement, atIndex: Int32) -> Int32 {
        var this = self
        let str = NSDecimalString(&this, Locale(identifier: "en_US_POSIX"))
        return sqlite3_bind_text(statement, atIndex, str.cString(using: .utf8), -1, SQLITE_TRANSIENT)
    }
}

/*if let t = ColumnType(rawValue: "FLOAT")?.type, let type = t.1 {
 print(type)
}*/
//ColumnType(rawValue: "NATIONAL VARYING CHARACTER").type 
public enum ColumnType: String {
    case BINARY; case BLOB; case VARBINARY
    case NCHAR; case NVARCHAR; case TEXT; case VARCHAR; case VARIANT; case VARYINGCHARACTER="VARYING CHARACTER"
    case CHAR; case CHARACTER; case CLOB; case NATIONALVARYINGCHARACTER="NATIONAL VARYING CHARACTER"; case NATIVECHARACTER="NATIVE CHARACTER"
    case DATE; case DATETIME; case TIME; case TIMESTAMP
    case BIGINT; case BIT; case BOOL; case BOOLEAN; case INT; case INT2; case INT8; case INTEGER; case MEDIUMINT; case SMALLINT; case TINYINT
    case NULL
    case DECIMAL; case DOUBLE; case DOUBLEPRECISION="DOUBLE PRECISION"; case FLOAT; case NUMERIC; case REAL
    var type: Int32 {
        switch self {
            case .BINARY,.BLOB,.VARBINARY: return SQLITE_BLOB
            case .NCHAR,.NVARCHAR,.TEXT,.VARCHAR,.VARIANT,.VARYINGCHARACTER: return SQLITE_TEXT
            case .CHAR,.CHARACTER,.CLOB,.NATIONALVARYINGCHARACTER,.NATIVECHARACTER: return SQLITE_TEXT
            case .DATE: return SQLITE_DATE
            case .DATETIME,.TIME,.TIMESTAMP: return SQLITE_DATETIME
            case .BIT,.BOOL,.BOOLEAN,.INT,.INT2,.INT8,.INTEGER,.MEDIUMINT,.SMALLINT,.TINYINT: return SQLITE_INTEGER
            case .NULL: return SQLITE_NULL
            case .DOUBLE,.DOUBLEPRECISION,.FLOAT,.NUMERIC,.REAL: return SQLITE_FLOAT
            case .DECIMAL,.BIGINT: return SQLITE_FLOAT
        }
    }
    
    func getMetaInfo(field: Column) -> String {
        var sql = " \(field.name) "
        if self.type == SQLITE_INTEGER {
            sql += "INTEGER"
            if field.primary_key == true || field.auto_increment == true { sql += " PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE" }
        }
        else if self.type == SQLITE_TEXT { sql += "TEXT" }
        else if self.type == SQLITE_DATE { sql += "DATE" }
        else if self.type == SQLITE_DATETIME { sql += "DATETIME" }
        else if self.type == SQLITE_FLOAT { sql += "TEXT" }  // store as it is
        else if self.type == SQLITE_BLOB { sql += "BINARY" }
        else { sql += "TEXT" }
        if let v = field.default_value { sql += " DEFAULT \(v) "}
        return sql
    }
    
}

