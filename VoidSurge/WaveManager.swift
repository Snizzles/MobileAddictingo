import Foundation

// MARK: - Wave Manager
// Continuous time-based difficulty escalation (Vampire Survivors style)

struct SpawnInstruction {
    let type: EnemyType
    let hpMultiplier: CGFloat
}

class WaveManager {
    private(set) var timeElapsed: TimeInterval = 0
    private(set) var bossCount: Int = 0
    private var spawnAccum: TimeInterval = 0
    private var bossTimer: TimeInterval = 120  // First boss at 2 min

    var onSpawnEnemy: ((SpawnInstruction) -> Void)?
    var onBossWave: (() -> Void)?

    func update(deltaTime dt: TimeInterval) {
        timeElapsed += dt
        spawnAccum += dt
        bossTimer -= dt

        if spawnAccum >= currentSpawnInterval {
            spawnAccum = 0
            onSpawnEnemy?(nextSpawnInstruction())
        }

        if bossTimer <= 0 {
            bossTimer = 120
            bossCount += 1
            onBossWave?()
        }
    }

    var currentSpawnInterval: TimeInterval {
        // Starts at 1.8s, reaches ~0.28s at 5 min
        let t = timeElapsed
        let interval = 1.8 / (1 + t / 35)
        return max(0.28, interval)
    }

    var hpMultiplier: CGFloat {
        return 1 + CGFloat(timeElapsed) / 100
    }

    var difficultyLabel: String {
        switch timeElapsed {
        case 0..<30:   return "ROOKIE"
        case 30..<90:  return "HUNTER"
        case 90..<180: return "VETERAN"
        case 180..<300:return "ELITE"
        case 300..<480:return "NIGHTMARE"
        default:       return "VOID"
        }
    }

    private func nextSpawnInstruction() -> SpawnInstruction {
        let type = randomEnemyType()
        return SpawnInstruction(type: type, hpMultiplier: hpMultiplier)
    }

    private func randomEnemyType() -> EnemyType {
        let t = timeElapsed
        var pool: [(EnemyType, Int)] = [(EnemyType, Int)]()

        // Always available
        pool.append((.grunt, 30))

        if t > 20 { pool.append((.speeder, 20)) }
        if t > 60 { pool.append((.tank, 12)) }
        if t > 90 { pool.append((.shooter, 15)) }
        if t > 150 { pool.append((.splitter, 12)) }

        // Increase tank/shooter frequency at high time
        if t > 240 {
            pool.append((.tank, 10))
            pool.append((.shooter, 12))
        }

        let totalWeight = pool.reduce(0) { $0 + $1.1 }
        var roll = Int.random(in: 0..<totalWeight)
        for (type, weight) in pool {
            roll -= weight
            if roll < 0 { return type }
        }
        return .grunt
    }
}
