
//  EntityManager.swift
//  War
//
//  Created by Developer on 9/17/16.
//  Copyright © 2016 JwitApps. All rights reserved.
//

import Foundation
import SpriteKit
import GameplayKit

class EntityManager {
    
    var componentSystems = [GKComponentSystem]() {
        didSet {
            entities.forEach { entity in
                componentSystems.forEach { system in
                    system.addComponent(foundIn: entity)
                }
            }
        }
    }
    
    var entities = Set<GKEntity>()
    var toRemove = Set<GKEntity>()
    
    var barriers: [GKEntity] {
        return []
    }
    
    let scene: SKScene
    
    init(scene: SKScene) {
        self.scene = scene
    }
    
    func add(entity: GKEntity) {
        entities.insert(entity)
        if let node = entity.component(ofType: RenderComponent.self)?.node {
            if !scene.children.contains(node) {
                scene.addChild(node)
            }
        }
        
        componentSystems.forEach { $0.addComponent(foundIn: entity) }
    }
    
    func remove(entity: GKEntity) {
        if let spriteNode = entity.component(ofType: RenderComponent.self)?.node {
            spriteNode.removeFromParent()
        }
        entities.remove(entity)
        toRemove.insert(entity)
    }
    
    func update(deltaTime: CFTimeInterval) {
        for componentSystem in componentSystems {
            componentSystem.update(deltaTime: deltaTime)
        }
        
        for curRemove in toRemove {
            for componentSystem in componentSystems {
                componentSystem.removeComponent(foundIn: curRemove)
            }
        }
        toRemove.removeAll()
    }
}
