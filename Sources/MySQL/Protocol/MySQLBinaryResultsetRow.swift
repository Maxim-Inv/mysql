import Bits
import Foundation

/// A Binary Protocol Resultset Row is made up of the NULL bitmap containing as many bits as we have columns
/// in the resultset + 2 and the values for columns that are not NULL in the Binary Protocol Value format.
struct MySQLBinaryResultsetRow {
    /// The values for this row.
    var values: [MySQLBinaryData]

    /// Parses a `MySQLBinaryResultsetRow` from the `ByteBuffer`.
    init(bytes: inout ByteBuffer, columns: [MySQLColumnDefinition41]) throws {
        let header = try bytes.requireInteger(as: Byte.self, source: .capture())
        guard header == 0x00 else {
            throw MySQLError(identifier: "resultHeader", reason: "Invalid result header", source: .capture())
        }

        let nullBitmap = try bytes.requireResultSetNullBitmap(count: columns.count, source: .capture())
        var values: [MySQLBinaryData] = []
        for (i, column) in columns.enumerated() {
            let storage: MySQLBinaryDataStorage?
            if nullBitmap.isNull(at: i) {
                storage = nil
            } else {
                switch column.columnType {
                case .MYSQL_TYPE_STRING,
                     .MYSQL_TYPE_VARCHAR,
                     .MYSQL_TYPE_VAR_STRING,
                     .MYSQL_TYPE_ENUM,
                     .MYSQL_TYPE_SET,
                     .MYSQL_TYPE_LONG_BLOB,
                     .MYSQL_TYPE_MEDIUM_BLOB,
                     .MYSQL_TYPE_BLOB,
                     .MYSQL_TYPE_TINY_BLOB,
                     .MYSQL_TYPE_GEOMETRY,
                     .MYSQL_TYPE_BIT,
                     .MYSQL_TYPE_DECIMAL,
                     .MYSQL_TYPE_NEWDECIMAL:
                    let data = try bytes.requireLengthEncodedData(source: .capture())
                    storage = .string(data)
                case .MYSQL_TYPE_LONGLONG:
                    if column.flags.get(.COLUMN_UNSIGNED) {
                        storage = try .uinteger8(bytes.requireInteger(endianness: .little, source: .capture()))
                    } else {
                        storage = try .integer8(bytes.requireInteger(endianness: .little, source: .capture()))
                    }
                case .MYSQL_TYPE_LONG, .MYSQL_TYPE_INT24:
                    if column.flags.get(.COLUMN_UNSIGNED) {
                        storage = try .uinteger4(bytes.requireInteger(endianness: .little, source: .capture()))
                    } else {
                        storage = try .integer4(bytes.requireInteger(endianness: .little, source: .capture()))
                    }
                case .MYSQL_TYPE_SHORT, .MYSQL_TYPE_YEAR:
                    if column.flags.get(.COLUMN_UNSIGNED) {
                        storage = try .uinteger2(bytes.requireInteger(endianness: .little, source: .capture()))
                    } else {
                        storage = try .integer2(bytes.requireInteger(endianness: .little, source: .capture()))
                    }
                case .MYSQL_TYPE_TINY:
                    if column.flags.get(.COLUMN_UNSIGNED) {
                        storage = try .uinteger1(bytes.requireInteger(endianness: .little, source: .capture()))
                    } else {
                        storage = try .integer1(bytes.requireInteger(endianness: .little, source: .capture()))
                    }
                default: throw MySQLError(identifier: "binaryColumn", reason: "Unsupported type: \(column)", source: .capture())
                }
            }
            let binary = MySQLBinaryData(type: column.columnType, isUnsigned: column.flags.get(.COLUMN_UNSIGNED), storage: storage)
            values.append(binary)
        }

        self.values = values
    }
}
