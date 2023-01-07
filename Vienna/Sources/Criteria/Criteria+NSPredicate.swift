//
//  Criteria+NSPredicate.swift
//  Vienna
//
//  Copyright 2022 Tassilo Karge
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

@objc
extension CriteriaTree {

    public convenience init?(predicate: NSPredicate) {
        self.init()
        guard let compound = predicate as? NSCompoundPredicate else {
            return nil
        }

        switch compound.compoundPredicateType {
        case .and:
            self.condition = .all
        case .or:
            self.condition = .any
        case .not:
            self.condition = .none
        default:
            self.condition = .invalid
        }

        let subPredicates: [NSPredicate]
        if compound.compoundPredicateType == .not && compound.subpredicates.count == 1,
           let notOrCompound = compound.subpredicates[0] as? NSCompoundPredicate,
           let notOrSubpredicates = notOrCompound.subpredicates as? [NSPredicate] {
            // Special case for "none" predicate, which is modeled by NSPredicateEditor as "not(or(...))"
            subPredicates = notOrSubpredicates
        } else if let directSubPredicates = compound.subpredicates as? [NSPredicate] {
            subPredicates = directSubPredicates
        } else {
            NSLog("No subpredicates in compound predicate \(compound)")
            return nil
        }

        for subPredicate in subPredicates {
            let criteriaElement: (NSObjectProtocol & CriteriaElement)?

            if let subCompound = subPredicate as? NSCompoundPredicate {
                // Look ahead to detect "not contains" predicate
                if subCompound.compoundPredicateType == .not,
                   subCompound.subpredicates.count == 1,
                   let subContainsPredicate = subCompound.subpredicates[0] as? NSComparisonPredicate,
                   subContainsPredicate.predicateOperatorType == .contains {
                    criteriaElement = Criteria(predicate: subContainsPredicate, notContains: true)
                } else {
                    criteriaElement = CriteriaTree(predicate: subCompound)
                }
            } else if let basicPredicate = subPredicate as? NSComparisonPredicate {
                criteriaElement = Criteria(predicate: basicPredicate)
            } else {
                criteriaElement = nil
            }

            if let criteriaElement = criteriaElement {
                self.criteriaTree.append(criteriaElement)
            } else {
                NSLog("Subpredicate \(subPredicate) of compound predicate \(compound) is corrupted, cannot be converted to CriteriaElement")
            }
        }
    }

    var predicate: NSPredicate {
        return buildPredicate()
    }

    private func buildPredicate() -> NSPredicate {

        let type: NSCompoundPredicate.LogicalType
        switch condition {
        case .any:
            type = .or
        case .none:
            type = .not
        case .all, .invalid:
            fallthrough
        @unknown default:
            type = .and
        }

        let subPredicates = self.criteriaTree.map { $0.predicate }

        if condition != .none {
            return NSCompoundPredicate(type: type, subpredicates: subPredicates)
        } else {
            // NSPredicateEditor only recognizes "none" predicate if modeled as "not(or(...))"
            return NSCompoundPredicate(type: type, subpredicates: [NSCompoundPredicate(orPredicateWithSubpredicates: subPredicates)])
        }
    }
}

@objc
extension Criteria {

    public convenience init?(predicate: NSPredicate) {
        self.init(predicate: predicate, notContains: false)
    }

    convenience init?(predicate: NSPredicate, notContains: Bool) {
        guard let comparison = predicate as? NSComparisonPredicate else {
            return nil
        }

        let field = comparison.leftExpression.constantValue as? String ?? comparison.leftExpression.keyPath
        let value = comparison.rightExpression.constantValue as? String ?? comparison.rightExpression.keyPath

        var fallback = false

        let criteriaOperator: Criteria.Operator
        switch field {
        case MA_Field_Folder:
            switch comparison.predicateOperatorType {
            case .notEqualTo:
                criteriaOperator = .notEqualTo
            case .equalTo:
                criteriaOperator = .equalTo
            default:
                fallback = true
                criteriaOperator = .equalTo
            }
        case MA_Field_Subject, MA_Field_Author, MA_Field_Text:
            switch comparison.predicateOperatorType {
            case .contains:
                if notContains {
                    criteriaOperator = .containsNot
                } else {
                    criteriaOperator = .contains
                }
            case .notEqualTo:
                criteriaOperator = .notEqualTo
            case .equalTo:
                criteriaOperator = .equalTo
            default:
                fallback = true
                criteriaOperator = .equalTo
            }
        case MA_Field_Date:
            switch comparison.predicateOperatorType {
            case .lessThan:
                criteriaOperator = .before
            case .lessThanOrEqualTo:
                criteriaOperator = .onOrBefore
            case .greaterThan:
                criteriaOperator = .after
            case .greaterThanOrEqualTo:
                criteriaOperator = .onOrAfter
            case .notEqualTo:
                criteriaOperator = .notEqualTo
            case .equalTo:
                criteriaOperator = .equalTo
            default:
                fallback = true
                criteriaOperator = .equalTo
            }
        case MA_Field_Read, MA_Field_Flagged, MA_Field_HasEnclosure, MA_Field_Deleted:
            switch comparison.predicateOperatorType {
            case .notEqualTo:
                // Not representable by predicate editor, because it would not
                // make sense to offer "== false" and "!= true" making things
                // ambiguous
                criteriaOperator = .notEqualTo
            case .equalTo:
                criteriaOperator = .equalTo
            default:
                fallback = true
                criteriaOperator = .equalTo
            }
        default:
            NSLog("Unknown field \(field)")
            fallback = comparison.predicateOperatorType != .equalTo
            criteriaOperator = .equalTo
        }

        if fallback {
            NSLog("Predicate for \(field) has unsuitable operator \(comparison.predicateOperatorType), will default to \(criteriaOperator)")
        }

        self.init(field: field, operatorType: criteriaOperator, value: value)
    }

    var predicate: NSPredicate {
        return buildPredicate()
    }

    private func buildPredicate() -> NSPredicate {

        let field = self.field
        let value = self.value
        let operatorType = self.operatorType

        if field == MA_Field_Date, let unit = DateUnit.allCases.first(where: { value.hasSuffix($0.rawValue) }) {
            let countString = value
                .replacingOccurrences(of: unit.rawValue, with: "")
                .trimmingCharacters(in: CharacterSet.whitespaces)
            guard let count = UInt(countString) else {
                fatalError("malformed criteria value \(value)")
            }
            let dateOperator = convertOperatorTypeForComparisonPredicate(operatorType)
            return DatePredicateWithUnit<Article>(field: MA_Field_Date, comparisonOperator: dateOperator, count: count, unit: unit) { (article: Article, field: String, comparisonOperator, count, unit) in
                true //TODO write an actual evaluation for the predicate that could be executed in code
            }
        } else {
            return buildComparisonPredicate(field, value, operatorType)
        }
    }

    func convertOperatorTypeForComparisonPredicate(_ operatorType: Criteria.Operator) -> NSComparisonPredicate.Operator {
        switch operatorType {
        case .equalTo:
            return .equalTo
        case .notEqualTo:
            return .notEqualTo
        case .lessThan:
            return .lessThan
        case .greaterThan:
            return .greaterThan
        case .lessThanOrEqualTo:
            return .lessThanOrEqualTo
        case .greaterThanOrEqualTo:
            return .greaterThanOrEqualTo
        case .contains:
            return .contains
        case .containsNot:
            return .contains // special case: negated later
        case .before:
            return .lessThan
        case .after:
            return .greaterThan
        case .onOrBefore:
            return .lessThanOrEqualTo
        case .onOrAfter:
            return .greaterThanOrEqualTo
        case .under:
            return .lessThan
        case .notUnder:
            return .greaterThanOrEqualTo
        default:
            NSLog("No proper predicate conversion found for \(operatorType), defaulting to \(NSComparisonPredicate.Operator.equalTo)")
            return .equalTo
        }
    }

    private func buildComparisonPredicate(_ field: String, _ value: String, _ operatorType: Criteria.Operator) -> NSPredicate {
        let left = NSExpression(forConstantValue: field)
        let right = NSExpression(forConstantValue: value)

        let type: NSComparisonPredicate.Operator = convertOperatorTypeForComparisonPredicate(operatorType)

        let comparisonPredicate: NSComparisonPredicate

        //TODO constants for fixed criteria values also for Criteria+SQL,
        // e.g. YES, NO, yesterday, today, last week, ...

        if field == MA_Field_Date && operatorType == .after && value == "yesterday" {
            // Use canonical "is today" instead of "is after yesterday"
            comparisonPredicate = NSComparisonPredicate(leftExpression: left, rightExpression: NSExpression(forConstantValue: "today"), modifier: .direct, type: .equalTo)
        } else if operatorType == .notEqualTo && (value == "No" || value == "Yes") {
            // Use canonical "is yes / is no" representation instead of allowing
            // ambiguous "is not yes - is no / is not no - is yes"
            let invertedRight = NSExpression(forConstantValue: value == "No" ? "Yes" : "No")
            comparisonPredicate = NSComparisonPredicate(leftExpression: left, rightExpression: invertedRight, modifier: .direct, type: .equalTo)
        } else {
            comparisonPredicate = NSComparisonPredicate(leftExpression: left, rightExpression: right, modifier: .direct, type: type)
        }

        if operatorType == .containsNot {
            // Representation for "not contains" in predicate differs because
            // "not contains" is no predicate operator
            return NSCompoundPredicate(notPredicateWithSubpredicate: comparisonPredicate)
        } else {
            return comparisonPredicate
        }
    }
}
