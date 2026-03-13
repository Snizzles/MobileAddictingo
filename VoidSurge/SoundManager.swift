import AVFoundation

// MARK: - Game Sounds (fully synthesized — no audio files required)

enum GameSound {
    case shoot
    case enemyHit
    case enemyDie
    case playerHit
    case levelUp
    case bossSpawn
    case xpCollect
}

private enum WaveType { case sine, square, sawtooth, noise }

class SoundManager {
    static let shared = SoundManager()

    private let engine    = AVAudioEngine()
    private var nodes:    [AVAudioPlayerNode] = []
    private var nodeIdx   = 0
    private let polyphony = 10
    private let rate:     Double = 44100

    private lazy var fmt = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!

    // Simple per-sound throttle to avoid audio spam
    private var lastPlayed: [String: TimeInterval] = [:]
    private let minInterval: [GameSound: TimeInterval] = [
        .shoot:      0.04,
        .enemyHit:   0.03,
        .enemyDie:   0.04,
        .xpCollect:  0.12,
        .playerHit:  0.15,
        .bossSpawn:  0.0,
        .levelUp:    0.0,
    ]

    private init() {
        for _ in 0..<polyphony {
            let n = AVAudioPlayerNode()
            engine.attach(n)
            nodes.append(n)
            engine.connect(n, to: engine.mainMixerNode, format: fmt)
        }
        engine.mainMixerNode.outputVolume = 0.65
        do { try engine.start() } catch { }
    }

    func play(_ sound: GameSound) {
        let key = "\(sound)"
        let now = CACurrentMediaTime()
        let minGap = minInterval[sound] ?? 0.05
        if let last = lastPlayed[key], now - last < minGap { return }
        lastPlayed[key] = now

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.synthesize(sound)
        }
    }

    // MARK: - Synthesis

    private func synthesize(_ sound: GameSound) {
        switch sound {
        case .shoot:
            // Short crisp blip — punchy and rapid-fire friendly
            tone(freq: 720, endFreq: 480, dur: 0.065, amp: 0.20, wave: .square)

        case .enemyHit:
            // Satisfying thwack
            tone(freq: 280, endFreq: 140, dur: 0.07, amp: 0.32, wave: .noise)

        case .enemyDie:
            // Crunch + pitch drop
            tone(freq: 320, endFreq: 80, dur: 0.14, amp: 0.38, wave: .sawtooth)

        case .playerHit:
            // Low thud — noticeable but not annoying
            tone(freq: 160, endFreq: 80, dur: 0.20, amp: 0.55, wave: .sawtooth)

        case .xpCollect:
            // Tiny high sparkle
            tone(freq: 1600, endFreq: 1200, dur: 0.04, amp: 0.13, wave: .sine)

        case .levelUp:
            // Ascending C major arpeggio — very satisfying
            let notes: [(Double, Double)] = [(523, 0.0), (659, 0.09), (784, 0.18), (1047, 0.27)]
            for (freq, delay) in notes {
                DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.tone(freq: freq, endFreq: freq * 1.02, dur: 0.16, amp: 0.30, wave: .sine)
                }
            }

        case .bossSpawn:
            // Heavy dungeon rumble
            tone(freq: 65, endFreq: 40, dur: 0.7, amp: 0.65, wave: .sawtooth)
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.tone(freq: 95, endFreq: 60, dur: 0.5, amp: 0.40, wave: .sawtooth)
            }
        }
    }

    // MARK: - PCM generation

    private func tone(freq: Double, endFreq: Double, dur: Double, amp: Float, wave: WaveType) {
        let frames = AVAudioFrameCount(rate * dur)
        guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frames),
              let ch  = buf.floatChannelData?[0] else { return }
        buf.frameLength = frames

        var phase: Double = 0
        for i in 0..<Int(frames) {
            let t        = Double(i) / rate
            let progress = t / dur
            let curFreq  = freq + (endFreq - freq) * progress
            phase += curFreq / rate
            if phase >= 1 { phase -= 1 }

            // Exponential decay envelope
            let env = Float(exp(-progress * 5.5))

            let raw: Float
            switch wave {
            case .sine:     raw = Float(sin(2 * .pi * phase))
            case .square:   raw = phase < 0.5 ? 1 : -1
            case .sawtooth: raw = Float(2 * phase - 1)
            case .noise:    raw = Float.random(in: -1...1)
            }
            ch[i] = raw * amp * env
        }

        let node = nextNode()
        node.stop()
        node.scheduleBuffer(buf)
        if !engine.isRunning { try? engine.start() }
        node.play()
    }

    private func nextNode() -> AVAudioPlayerNode {
        defer { nodeIdx = (nodeIdx + 1) % polyphony }
        return nodes[nodeIdx]
    }
}
