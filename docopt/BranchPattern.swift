//
//  BranchPattern.swift
//  docopt
//
//  Created by Pavel S. Mazurin on 3/1/15.
//  Copyright (c) 2015 kovpas. All rights reserved.
//

import Foundation

internal class BranchPattern : Pattern, Equatable {
    var children: Array<Pattern>
    override internal var description: String {
        get {
            return "BranchPattern(\(children))"
        }
    }

    internal convenience init(_ child: Pattern) {
        self.init([child])
    }

    internal init(_ children: Array<Pattern>) {
        self.children = children
    }
    
    override internal func fixIdentities(_ unq: Array<LeafPattern>? = nil) {
        var uniq: Array<LeafPattern> = unq ?? Array(Set(flat()))
        
        for var i = 0; i < count(children); i++ {
            let child = children[i]
            if let leafChild = child as? LeafPattern {
                assert(contains(uniq, leafChild));
                children[i] = uniq[find(uniq, leafChild)!]
            } else {
                child.fixIdentities(uniq)
            }
        }
    }
    
    override internal func flat<T: Pattern>(type: T.Type) -> Array<T> {
        if let cast = self as? T {
            return [cast]
        }
        var result = Array<T>()
        for child in children {
            result += child.flat(T)
        }
        return result
    }
}

internal func ==(lhs: BranchPattern, rhs: BranchPattern) -> Bool {
    return lhs.children == rhs.children
}