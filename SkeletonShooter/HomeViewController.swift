//
//  HomeViewController.swift
//  SkeletonShooter
//
//  Created by Ivan on 2019-04-03.
//  Copyright © 2019 CentennialCollege. All rights reserved.
//

import UIKit

class HomeViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        let defaults = UserDefaults.standard
        if let gameScore = defaults.value(forKey: "score") {
            let score = gameScore as! Int
            scoreLabel.text = "score: \(String(score))"
        }
    }
    
    @IBAction func onPlayButton(_ sender: Any) {
        performSegue(withIdentifier: "mainToGame", sender: self)
    }
    
    @IBOutlet weak var scoreLabel: UILabel!
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
    }
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */
    
}

