//
//  Drawer.swift
//  War
//
//  Created by Developer on 9/18/16.
//  Copyright © 2016 JwitApps. All rights reserved.
//

import GameplayKit
import SpriteKit

struct DrawerItem {
    let node: SKNode
    lazy var entity: GKEntity = {
        let entity = self.createEntity()
        self.node.entity = entity
        return self.createEntity()
    }()
    private let createEntity: ()->(GKEntity)
    
    init(node: SKNode, createEntity: @escaping ()->(GKEntity)) {
        self.node = node
        self.createEntity = createEntity
    }
    
    func copy() -> DrawerItem {
        let nodeCopy = node.copy() as! SKNode
        return DrawerItem(node: nodeCopy, createEntity: createEntity)
    }
}

class Drawer: SKShapeNode {
    
    var customConstraints = [SKConstraint]()
    
    // holds a copyable entity type for each node
    var items = [DrawerItem]()
    
    var addEntity: ((GKEntity)->())?
    
    var movingItem: DrawerItem?
    
    func add(item node: SKNode, withEntity createEntity: @escaping ()->(GKEntity)) {
        guard let name = node.name else { fatalError("item added to drawer has no name") }
        
        items.append(DrawerItem(node: node, createEntity: createEntity))
        
        for item in items where !name.hasPrefix("drawer-") {
            item.node.name = "drawer-" + name
        }
        
        removeAllChildren()
        redrawItems()
    }
    
    func touchDown(atPoint pos : CGPoint) {
        guard let scene = scene else { return }
        let convertedPoint = convert(pos, from: scene)
        
        guard let touchedItem = (items.filter {
            $0.node == atPoint(convertedPoint)
        }.first) else {
            return
        }
        
        // copy node and entity, reassociate them
        movingItem = touchedItem.copy()
        movingItem!.node.position = pos

        scene.addChild(movingItem!.node)
    }
    
    func touchMoved(toPoint pos : CGPoint) {
        movingItem?.node.position = pos
    }
    
    func touchUp(atPoint pos : CGPoint) {
        if var item = movingItem {
            let oldNode = item.node
            let newNode = item.entity.component(ofType: RenderComponent.self)?.node
            
            oldNode.removeFromParent()
            newNode?.name = oldNode.name?.replacingOccurrences(of: "drawer-", with: "")
            newNode?.position = oldNode.position
            self.addEntity?(item.entity)
        }
        movingItem = nil
    }
    
    private func redrawItems() {
        items.forEach {
            addChild($0.node)
        }
    }
    
}
