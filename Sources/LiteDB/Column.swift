//
//  Column.swift
//
//  Created by Emmanuel Adigun on 2022/05/27.
//  Copyright © 2022 Zignal Systems. All rights reserved.
//

import Foundation

open class Column: NSObject {
    var name: String
    private(set) var type: ColumnType = .TEXT //defaults..
    private(set) var primary_key = false
    private(set) var auto_increment = false
    private(set) var default_value: Any?
    var value: Any? = nil
    
    public init(name: String, type: ColumnType = .TEXT, default_value: Any? = nil, primary_key: Bool = false, auto_increment: Bool = false) {
        self.name = name
        self.type = type
        self.default_value = default_value
        self.primary_key = primary_key
        self.auto_increment = auto_increment
        if auto_increment == true || primary_key == true { self.type = .INTEGER }
    }
    
    func isPrimaryKey() -> Bool { return self.primary_key == true }
    func isAutoIncrement() -> Bool { return self.auto_increment == true }
    
}

