//
//  main.swift
//  nanoChallenge
//
//  Created by Gustavo Diefenbach on 20/03/23.
//

import Foundation
import AVFoundation

var jumpSound: AVAudioPlayer?
var backgroundSound: AVAudioPlayer?
var emojiSelecter: String = "👁️"

enum Comands : UInt8 {
    case space = 32
    case quit = 113
    case one = 49
    case two = 50
    case three = 51
    case four = 52
    case five = 53
}

public typealias TerminalStyleCode = (open: String, close: String)

public struct TerminalStyle {
    public static let bold: TerminalStyleCode = ("\u{001B}[1m", "\u{001B}[22m")
    public static let underline: TerminalStyleCode = ("\u{001B}[4m", "\u{001B}[24m")
    public static let red: TerminalStyleCode = ("\u{001B}[31m", "\u{001B}[0m")
    public static let reset: TerminalStyleCode = ("\u{001B}[0m", "")
}

extension String {
    // Enable/disable colorization
    public static var isColorizationEnabled = true
    
    public func bold() -> String {
        return applyStyle(TerminalStyle.bold)
    }
    
    public func underline() -> String {
        return applyStyle(TerminalStyle.underline)
    }
    
    public func reset() -> String {
        guard String.isColorizationEnabled else { return self }
        return  "\u{001B}[0m" + self
    }
    
    public func foregroundColor(_ color: TerminalColor) -> String {
        return applyStyle(color.foregroundStyleCode())
    }
    
    public func backgroundColor(_ color: TerminalColor) -> String {
        return applyStyle(color.backgroundStyleCode())
    }
    
    public func colorize(_ foreground: TerminalColor) -> String{
        return applyStyle(foreground.foregroundStyleCode())//.applyStyle(background.backgroundStyleCode())
    }
    
    public func uncolorized() -> String {
        guard let regex = try? NSRegularExpression(pattern: "\\\u{001B}\\[([0-9;]+)m") else { return self }
        
        return regex.stringByReplacingMatches(in: self, options: [], range: NSRange(0..<self.count), withTemplate: "")
    }
    
    private func applyStyle(_ codeStyle: TerminalStyleCode) -> String {
        guard String.isColorizationEnabled else { return self }
        let str = self.replacingOccurrences(of: TerminalStyle.reset.open, with: TerminalStyle.reset.open + codeStyle.open)
        
        return codeStyle.open + str + TerminalStyle.reset.open
    }
}

public enum TerminalColor: UInt8 {
    
    case black = 0
    case red

    public func foregroundStyleCode() -> TerminalStyleCode {
        return ("\u{001B}[38;5;\(self.rawValue)m", TerminalStyle.reset.open)
    }
    
    public func backgroundStyleCode() -> TerminalStyleCode {
        return ("\u{001B}[48;5;\(self.rawValue)m", TerminalStyle.reset.open)
    }
}


enum MenuComands : Int {
    case menuStart = 1
    case menuCharacter = 2
    case menuWrong = 9
}

enum ErrorKeyboard : Error{
    case wrongKey
}

public class SoundManeger {
    static var shared : SoundManeger = SoundManeger()
    static var shared2 : SoundManeger = SoundManeger()
    
    func playJumpSound() {
        let url = Bundle.main.url(forResource: "jump", withExtension: "mp3")
        
        do {
            jumpSound = try AVAudioPlayer(contentsOf: url ?? URL(string: "")!)
            //jumpSound?.volume = self.volumeJump
            jumpSound?.play()
        } catch {
            print("Nao encontrei o som de JUMP")
        }
    }

    func playMusic() {
        let url = Bundle.main.url(forResource: "background", withExtension: "mp3")
    
        do {
            backgroundSound = try AVAudioPlayer(contentsOf: url ?? URL(string: "")!, fileTypeHint: AVFileType.mp3.rawValue)
           // backgroundSound?.volume = self.volumeBack
            backgroundSound?.play()
        } catch {
            print("Nao encontrei o som de BACKGROUND")
        }
    }
}

extension FileHandle {
    func enableRawMode() -> termios {
        var raw = termios()
        tcgetattr(self.fileDescriptor, &raw)
        
        let original = raw
        raw.c_lflag &= ~UInt(ECHO | ICANON)
        tcsetattr(self.fileDescriptor, TCSADRAIN, &raw)
        return original
    }
    
    func restoreRawMode(originalTerm: termios) {
        var term = originalTerm
        tcsetattr(self.fileDescriptor, TCSADRAIN, &term)
    }
}

func getch() -> UInt8 {
    let handle = FileHandle.standardInput
    let term = handle.enableRawMode()
    defer { handle.restoreRawMode(originalTerm: term) }
    
    var byte: UInt8 = 0
    read(handle.fileDescriptor, &byte, 1)
    return byte
}

class FlappyBird {
    var a : Int = 0
    
    //Screen
    var screenX : Int = 0
    var screenY : Int = 0
    
    //Screen Aperence
    var emojiBackground: String = ""
    var emojiObstacle: String = ""
    var emojiUser: String = ""
    
    //Struction Scene
    var sky = Array(repeating: "", count: 1)
    var floor = Array(repeating: "", count: 1)
    var matriz = Array(repeating: Array(repeating: "", count: 1), count: 1)
    
    //Construitive
    let spaceBetweenObstacle = 17
    let constGrav : Int = 4
    var countSpace : Int = 0
    var velocity : TimeInterval = 0.2
    
    //User
    var position : Int = 2
    var gravity: Int = 0
    
    //Controllers
    var score : Int = 0
    var lastValue : Int = 0
    var loose : Bool = false
    var controlMenu : Int = 1

    //Music Controllers
    let volumeJump : Float = 0.5
    let volumeBack : Float = 1
    
    
    //Music
    func playJumpSound() {
        let url = Bundle.main.url(forResource: "jump", withExtension: "mp3")
        
        do {
            jumpSound = try AVAudioPlayer(contentsOf: url ?? URL(string: "")!)
            jumpSound?.volume = self.volumeJump
            jumpSound?.play()
        } catch {
            print("Nao encontrei o som de JUMP")
        }
    }

    func playMusic() {
        let url = Bundle.main.url(forResource: "background", withExtension: "mp3")
        
        do {
            backgroundSound = try AVAudioPlayer(contentsOf: url ?? URL(string: "")!, fileTypeHint: AVFileType.mp3.rawValue)
            backgroundSound?.volume = self.volumeBack
            backgroundSound?.play()
        } catch {
            print("Nao encontrei o som de BACKGROUND")
        }
    }
    
    func newFrame( blackSpace: Bool ){
        var emoji = emojiBackground
        
        let positionNewFrame = Int.random(in: 1...self.screenY-2)
        
        for y in 0...self.screenY-1 {
            
            if (!blackSpace) {
                if ((positionNewFrame+1 >= y) && (positionNewFrame-1 <= y)) {
                    emoji = self.emojiBackground
                } else {
                    emoji = self.emojiObstacle
                }
            } else{
                emoji = self.emojiBackground
            }
            
            //print(emoji,positionNewFrame+1,y,positionNewFrame-1)
            self.matriz[y][screenX-1] = emoji
        }
         
    }
    
    func move(){
        
        for auxY in 0...screenY-1 {
            for auxX in 0...screenX-2 {
                matriz[auxY][auxX] = matriz[auxY][auxX+1]
            }
        }
        
        gravity += 1
        
        if self.gravity >= self.constGrav {
            if self.position < self.screenY-1 {
                self.position += 1 //soma 1, mas move para baixo o usuario
            } else {
                //teste colisao floor
                if (self.lastValue==self.position) {
                    self.loose = true
                    showGameOver()
                } else {
                    self.lastValue = self.position
                }
            }
            gravity = 0
        }
        
        self.countSpace += 1
        if(self.countSpace >= self.spaceBetweenObstacle) {
            self.countSpace = 0
            newFrame(blackSpace: false)
        } else {
            newFrame(blackSpace: true)
        }

        if self.matriz[position][1] == self.emojiObstacle {
            self.loose = true
        }

    }
    
    func show(){
        self.matriz[self.position][0] = self.emojiUser
        
        print(self.sky.reduce("", +))
        
        for i in 0...self.screenY-1 {
            print(self.matriz[i].reduce("", +))
        }
        
        print(self.floor.reduce("", +))
        
        //calculo dos pontos
        self.score += 1
        if (self.score >= self.screenX-1) {
            print("|    SCORE: \((self.score-self.screenX)/(self.spaceBetweenObstacle))) |")
        } else{
            print("|    SCORE: \(0) |")
        }
    }
    
    func keyboardCommand(c: UInt8) -> Bool{
        switch c {
            case Comands.quit.rawValue: //q
                return(false)
            case Comands.space.rawValue: //space
                SoundManeger.shared2.playJumpSound()
                //playJumpSound()
                position = position > 0 ? position-1 : position
                return(true)
            default:
                return(true)
        }
    }
    
    func createScene(){
        matriz = Array(repeating: Array(repeating: emojiBackground, count: self.screenX), count: self.screenY)
        sky = Array(repeating: "☁️ ", count: self.screenX)
        floor = Array(repeating: "🌱", count: self.screenX)
    }
    
    //****************
    
    func showMenu() {
        print(self.sky.reduce("", +))
        print("")
        print("                                                 FLAPPY BIRD  \n                                               TERMINAL EDITION".bold())
        print("")
        print("                                           Current Character: \(self.emojiUser)")
        print("")
        print("                                     ","SELECT THE ACTION DESIRED:".bold().underline())
        print("                                 1: Start Game")
        print("                                 2: Choose Character")
        print("                                 3: Set Game Difficulty Level", "🚧 IN DEVELOPMENT 🚧".bold().colorize(.red))
        print("")
        print(self.floor.reduce("", +))
        
    }
    
    func showEmojiMenu() {
        print(self.sky.reduce("", +))
        print("")
        print("")
        print("                                              CHOOSE CHARACTER")
        print("")
        print("                                             1: Old School -> 🐔")
        print("                                             2: Mr. Frog -> 🐸")
        print("                                             3: Miss Koala -> 🐨")
        print("                                             4: Mr. Pig -> 🐷")
        print("                                             5: Miss. Rabbit -> 🐰")
        print("")
        print("")
        print(self.floor.reduce("", +))
    }
    
    func showGameOver (){
        print(self.sky.reduce("", +))
        print("")
        print("")
        print("")
        print("")
        print("                                                 GAME OVER".bold().colorize(.red))
        print("")
        print("")
        print("")
        print("")
        print("")
        print("")
        print(self.floor.reduce("", +))
    }
    
    func selectUserEmojis(c : UInt8) -> Int {
        switch c {
        case Comands.one.rawValue:
            self.emojiUser = "🐔"
        case Comands.two.rawValue:
            self.emojiUser = "🐸"
        case Comands.three.rawValue:
            self.emojiUser = "🐨"
        case Comands.four.rawValue:
            self.emojiUser = "🐷"
        case Comands.five.rawValue:
            self.emojiUser = "🐰"
        default:
            return(MenuComands.menuWrong.rawValue)
        }
        return(MenuComands.menuStart.rawValue)
    }

    func selectMenu(c : UInt8) -> Int{
        switch c {
        case Comands.one.rawValue:
            return(MenuComands.menuStart.rawValue)
        case Comands.two.rawValue:
            return(MenuComands.menuCharacter.rawValue)
        default:
            return(MenuComands.menuWrong.rawValue)
        }
    }

    
    init (screenX: Int, screenY: Int, emojiBackground: String, emojiObstacle : String, emojiUser : String ){
        self.screenX = screenX
        self.screenY = screenY
        self.emojiBackground = emojiBackground
        self.emojiObstacle = emojiObstacle
        self.emojiUser = emojiUser
        self.position = screenY/2 //inicia o usuario no meio da matriz
    }
}

var flagGame : Bool = true

let game : FlappyBird = FlappyBird(screenX: 60, screenY: 10, emojiBackground: "◾️", emojiObstacle: "🟩", emojiUser: "🐔")

func thereadScreen(){
    while flagGame {
        game.move()
        
        if(game.loose) {
            flagGame = false
            game.showGameOver()
        } else {
            game.show()
        }
            
        
        Thread.sleep(forTimeInterval: game.velocity)
    }
}

// Create a new thread that will execute thereadUpdate()
let thread = Thread {
    thereadScreen()
}

game.createScene()
game.controlMenu = MenuComands.menuStart.rawValue
game.showMenu()

while (game.controlMenu > 0) {
    
    //game.showEmojiMenu()
    let c = getch()
    
    switch game.controlMenu {
    case MenuComands.menuStart.rawValue:
        game.controlMenu = game.selectMenu(c: c)
    case MenuComands.menuCharacter.rawValue:
        game.controlMenu = game.selectUserEmojis(c: c)
    default:
        print("Wrong Selection")
    }

    switch game.controlMenu {
    case MenuComands.menuStart.rawValue:
        game.showMenu()
        game.controlMenu = 0
    case MenuComands.menuCharacter.rawValue:
        game.showEmojiMenu()
        game.controlMenu = MenuComands.menuCharacter.rawValue
    default:
        break
    }
}

flagGame = true
game.createScene()

SoundManeger.shared.playMusic()
//game.playMusic()

thread.start()

while flagGame {
    let char = getch()
    
    flagGame = game.keyboardCommand(c: char)
    
    if(game.loose) {
        flagGame = false
        thread.cancel()
    }
}

game.showGameOver()


