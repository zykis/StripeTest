//
//  ViewController.swift
//  StripeTest
//
//  Created by Артём Зайцев on 19.11.2019.
//  Copyright © 2019 Артём Зайцев. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        PaymentObserver.shared.applePayControllerDelegate = self
        // Do any additional setup after loading the view.
    }

    @IBAction func chargeMoneyPressed() {
        PaymentObserver.shared.handleApplePayButtonPressed()
    }
    
    @IBAction func sendMoneyPressed() {
        
    }
}

