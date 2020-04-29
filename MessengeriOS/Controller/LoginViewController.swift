//
//  ViewController.swift
//  MessengeriOS
//

import UIKit
import FirebaseAuth

class LoginViewController: UIViewController {

    @IBOutlet weak var nameTF: UITextField!
   
    override func viewDidLoad() {
        super.viewDidLoad()

        if UserDefaultsClass.displayName != nil {
            let vc = self.storyboard!.instantiateViewController(identifier: "TopicsViewController") as TopicsViewController
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        //Sets the focus on the text field
        nameTF.becomeFirstResponder()
    }
    
    // MARK: - Actions
    @IBAction func GoButton(_ sender: UIButton) {
        //Checks for textField is empty
        if let name = nameTF.text, !name.isEmpty {
            //Saves the user name to UserDafaults
            UserDefaultsClass.displayName = name
            
            //Signs in as Anonymous user in Firebase
            Auth.auth().signInAnonymously(completion: nil)
            
            //Navigates to the Topics screen
            let vc = self.storyboard!.instantiateViewController(identifier: "TopicsViewController") as TopicsViewController
            self.navigationController?.pushViewController(vc, animated: true)
        }
        else {
            nameTF.resignFirstResponder()
            showMissingNameAlert()
        }
    }

    // MARK: - Helpers
    //Shows an alert if the nameTF is empty
    private func showMissingNameAlert() {
        let ac = UIAlertController(title: "Name Required", message: "Please enter a name.", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "Okay", style: .default, handler: { _ in
            DispatchQueue.main.async {
                self.nameTF.becomeFirstResponder()
            }
        }))
        present(ac, animated: true, completion: nil)
    }
}

