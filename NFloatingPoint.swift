//
//  NFloatingPoint.swift
//  CeedNumerics
//
//  Created by Raphael Sebbe on 31/05/2019.
//  Copyright © 2019 Creaceed. All rights reserved.
//

import Foundation

// using BinaryFloatingPoint instead of FloatingPoint, which provides broader built-in capabilities.
public protocol NFloatingPoint: BinaryFloatingPoint, CustomStringConvertible where Self.RawSignificand : FixedWidthInteger {
	
}

// note: we may sometimes need this "where Self.RawSignificand : FixedWidthInteger"
extension NFloatingPoint {
	public var roundedIntValue: Int {
		return Int(self.rounded())
	}
	public var doubleValue: Double {
		return Double(self)
	}
	public var floatValue: Float {
		return Float(self)
	}
}
