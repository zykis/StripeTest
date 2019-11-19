//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
// 

import Foundation
import StoreKit
import Stripe

let kMerchantID = "merchant.id.vinci.corp.messenger"

@objc class PaymentObserver: NSObject
{
    var applePayControllerDelegate: UIViewController?
    var paymentSucceeded: Bool = false
    var clientSecret: String?
    
    @objc static let shared = PaymentObserver()
    private override init() {}
}

protocol ApplePayControllerProtocol {
    func presentPaymentController(paymentController: PKPaymentAuthorizationViewController)
}

extension PaymentObserver {
    func handleApplePayButtonPressed() {
        if (Stripe.deviceSupportsApplePay()) {
            let paymentRequest = Stripe.paymentRequest(withMerchantIdentifier: kMerchantID, country: "RU", currency: "RUB")
            
            let itemLabel = "Talala withdraw"
            let itemAmount: NSDecimalNumber = 399.0
            
            paymentRequest.paymentSummaryItems = [
                PKPaymentSummaryItem(label: itemLabel, amount: itemAmount),
                PKPaymentSummaryItem(label: "Talala Inc.", amount: itemAmount)
            ]
            
            // get intent from server
            if let url = URL(string: "http://35.158.212.139:5000/intent") {
                let params: [String: Any] = ["amount": itemAmount.floatValue * 100, "currency": "rub"]
                
                do {
                    let d = try JSONSerialization.data(withJSONObject: params, options: [])
                    
                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.httpBody = d
                    
                    let dataTask = URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
                        if error == nil, let data = data {
                            do {
                                let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
                                self.clientSecret = json["client_secret"] as? String
                                // Submit payment request
                                if Stripe.canSubmitPaymentRequest(paymentRequest),
                                    let paymentAuthorizationViewController = PKPaymentAuthorizationViewController(paymentRequest: paymentRequest) {
                                    paymentAuthorizationViewController.delegate = self
                                    DispatchQueue.main.async {
                                        self.applePayControllerDelegate?.present(paymentAuthorizationViewController, animated: true)
                                    }
                                } else {
                                    fatalError("There is a problem with your Apple Pay configuration")
                                }
                            } catch {
                                print(error)
                            }
                        }
                    }
                    dataTask.resume()
                } catch {
                    print(error)
                }
            }
        } else {
            let alert = UIAlertController(title: "ApplePay disabled", message: "Enable ApplePay and make sure you have a card, connected to it to proceed", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
            applePayControllerDelegate?.present(alert, animated: true, completion: nil)
        }
    }
}


extension PaymentObserver: PKPaymentAuthorizationViewControllerDelegate, STPAuthenticationContext {
    func authenticationPresentingViewController() -> UIViewController {
        return applePayControllerDelegate!
    }
    
    @available(iOS 11.0, *)
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, handler: @escaping (PKPaymentAuthorizationResult) -> Void) {
        // Convert the PKPayment into a PaymentMethod
        STPAPIClient.shared().createPaymentMethod(with: payment) { (paymentMethod: STPPaymentMethod?, error: Error?) in
            guard let paymentMethod = paymentMethod, error == nil, let clientSecret = self.clientSecret else {
                let alert = UIAlertController(title: "Payment error", message: error?.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
                DispatchQueue.main.async {
                    self.applePayControllerDelegate?.present(alert, animated: true, completion: nil)
                }
                return
            }
            let paymentIntentParams = STPPaymentIntentParams(clientSecret: clientSecret)
            paymentIntentParams.paymentMethodId = paymentMethod.stripeId
            
            // Confirm the PaymentIntent with the payment method
            STPPaymentHandler.shared().confirmPayment(withParams: paymentIntentParams, authenticationContext: self) { (status, paymentIntent, error) in
                switch (status) {
                case .succeeded:
                    // Save payment success
                    self.paymentSucceeded = true
                    handler(PKPaymentAuthorizationResult(status: .success, errors: nil))
                case .canceled:
                    handler(PKPaymentAuthorizationResult(status: .failure, errors: nil))
                case .failed:
                    // Save/handle error
                    let errors = [STPAPIClient.pkPaymentError(forStripeError: error)].compactMap({ $0 })
                    handler(PKPaymentAuthorizationResult(status: .failure, errors: errors))
                @unknown default:
                    handler(PKPaymentAuthorizationResult(status: .failure, errors: nil))
                }
            }
        }
    }
    
    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        // Dismiss payment authorization view controller
        controller.dismiss(animated: true, completion: {
            if (self.paymentSucceeded) {
                let alert = UIAlertController(title: "Payment", message: "Payment proceeded successfully", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
                self.applePayControllerDelegate?.present(alert, animated: true, completion: nil)
            } else {
                let alert = UIAlertController(title: "Payment", message: "Payment proceed error", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
                self.applePayControllerDelegate?.present(alert, animated: true, completion: nil)
            }
        })
    }
}
