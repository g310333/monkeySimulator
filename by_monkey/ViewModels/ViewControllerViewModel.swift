//
//  ViewControllerViewModel.swift
//  by_monkey
//

import Foundation

final class ViewControllerViewModel {

    var onTitleChange: ((String) -> Void)?

    func viewDidLoad() {
        onTitleChange?("by_monkey")
    }

}
