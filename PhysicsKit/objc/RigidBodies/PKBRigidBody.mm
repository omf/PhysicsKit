//
//  PKBRigidBody.m
//  BulletPhysics
//
//  Created by Adam Eisfeld on 2020-06-10.
//  Copyright © 2020 adam. All rights reserved.
//

#import "PKBRigidBody.h"
#import "PKBRigidBody+Internal.h"
#import "PKBStructs.h"
#import "PKBStructs+Internal.h"
#import "NSValue+PKBStructs.h"
#import "PKBGeometry.h"
#import "PKBPolygon.h"
#import "PKBVertex.h"
#import "PKBCollisionShape.h"
#import "PKBCollisionShape+Internal.h"
#import "PKBPhysicsWorld.h"

@interface PKBRigidBody() {
    
    PKBCollisionShape *_collisionShape;

}

@end

@implementation PKBRigidBody {}

// MARK: Initialization

- (void)setOnGetVisualTransform:(PKBMotionStateTransformGetBlock)onGetVisualTransform {
    _onGetVisualTransform = onGetVisualTransform;
    if (onGetVisualTransform) {
        PKBMotionState *motionState = new PKBMotionState(self);
        _c_body->setMotionState(motionState);
    }
}

- (void)setOnSetVisualTransform:(PKBMotionStateTransformSetBlock)onSetVisualTransform {
    _onSetVisualTransform = onSetVisualTransform;
    if (!_onGetVisualTransform && !_onSetVisualTransform) {
        _c_body->setMotionState(nil);
    }
}

class PKBMotionState : public btMotionState {
    
    void *motionStateObject;
    
    public:
    PKBMotionState(PKBRigidBody *rigidBody) : motionStateObject((__bridge void *)rigidBody){
    
    }
  
    virtual ~PKBMotionState() {}
  
    virtual void getWorldTransform(btTransform &centerOfMassWorldTrans) const override {
        PKBRigidBody *rigidBody = (__bridge PKBRigidBody *)motionStateObject;
        if (rigidBody.onGetVisualTransform) {
            PKMatrix4 visualTransform = rigidBody.onGetVisualTransform();
            centerOfMassWorldTrans = btTransformMakeFrom(visualTransform);
        }
    }
  
    virtual void setWorldTransform(const btTransform &centerOfMassWorldTrans) override {
        PKBRigidBody *rigidBody = (__bridge PKBRigidBody *)motionStateObject;
        if (rigidBody.onSetVisualTransform) {
            PKMatrix4 physicsTransform = PKMatrix4MakeFrom(centerOfMassWorldTrans);
            rigidBody.onSetVisualTransform(physicsTransform);
        }
    }
    
};

- (instancetype)initWithCollisionShape: (PKBCollisionShape *)collisionShape rigidBodyType: (PKBRigidBodyType)rigidBodyType mass:(float)mass {
    self = [super init];
    if (self) {
        
        _rigidBodyType = rigidBodyType;
        _collisionShape = collisionShape;
        
        btVector3 _c_bodyInertia = btVector3(0,0,0);
        if (rigidBodyType == PKBRigidBodyTypeDynamic) {
            _collisionShape.c_shape->calculateLocalInertia(mass, _c_bodyInertia);
        }
        
        btRigidBody::btRigidBodyConstructionInfo c_constructionInfo = btRigidBody::btRigidBodyConstructionInfo(mass, nil, _collisionShape.c_shape, _c_bodyInertia);
        c_constructionInfo.m_mass = mass;
        
        _c_body = new btRigidBody(c_constructionInfo);
        _c_body->setUserPointer((__bridge void*)self);
        
        if (rigidBodyType == PKBRigidBodyTypeDynamic) {
            
        } else if (rigidBodyType == PKBRigidBodyTypeKinematic) {
            
            _c_body->setCollisionFlags( _c_body->getCollisionFlags() | btCollisionObject::CF_KINEMATIC_OBJECT);
            _c_body->setActivationState(DISABLE_DEACTIVATION);
            
        } else if (rigidBodyType == PKBRigidBodyTypeStatic) {
            
            _c_body->setCollisionFlags( _c_body->getCollisionFlags() | btCollisionObject::CF_STATIC_OBJECT);
            
        }
        
    }
    return self;
}

// MARK: Deallocation

- (void)dealloc {
    _collisionShape = nil;
    delete _c_body->getMotionState();
    if (_c_body) {
        delete _c_body;
    }
    [_physicsWorld internalRemoveRigidBody:self];

}

// MARK: Transform

- (PKVector3)position {
    if (_c_body) {
        btTransform c_transform = _c_body->getWorldTransform();
        btVector3 c_position = c_transform.getOrigin();
        return PKVector3Make(c_position.x(), c_position.y(), c_position.z());
    } else {
        return PKVector3Make(0, 0, 0);
    }
}

- (void)setPosition:(PKVector3)position {
    if (_c_body) {
        btTransform c_transform = _c_body->getWorldTransform();
        btVector3 c_position = btVector3(position.x, position.y, position.z);
        c_transform.setOrigin(c_position);
        _c_body->setWorldTransform(c_transform);
    }
}

- (PKQuaternion)orientation {
    PKQuaternion output;
    if (_c_body) {
        btTransform c_transform = _c_body->getWorldTransform();
        btQuaternion c_orientation = c_transform.getRotation();
        output.x = c_orientation.x();
        output.y = c_orientation.y();
        output.z = c_orientation.z();
        output.w = c_orientation.w();
    }
    return output;
}

- (void)setOrientation:(PKQuaternion)orientation {
    if (_c_body) {
        
        btTransform c_transform = _c_body->getWorldTransform();
        
        btQuaternion c_orientation;
        c_orientation.setValue(orientation.x, orientation.y, orientation.z, orientation.w);
        
        c_transform.setRotation(c_orientation);
        _c_body->setWorldTransform(c_transform);
    }
}

- (PKVector3)eulerOrientation {
    PKVector3 output;
    if (_c_body) {
        btTransform c_transform = _c_body->getWorldTransform();
        btQuaternion c_orientation = c_transform.getRotation();
        c_orientation.getEulerZYX(output.z, output.y, output.x);
    }
    return output;
}

- (void)setEulerOrientation:(struct PKVector3)eulerOrientation {
    btTransform c_transform = _c_body->getWorldTransform();
    btQuaternion c_orientation = c_transform.getRotation();
    c_orientation.setEulerZYX(eulerOrientation.z, eulerOrientation.y, eulerOrientation.x);
    c_transform.setRotation(c_orientation);
    _c_body->setWorldTransform(c_transform);
}

- (PKMatrix4)transform {
    if (_c_body) {
        btTransform c_transform = _c_body->getWorldTransform();
        return PKMatrix4MakeFrom(c_transform);
    } else {
        return PKMatrix4MakeIdentity();
    }
}

- (void)setTransform:(PKMatrix4)transform {
    if (_c_body) {
        btTransform c_transform = btTransformMakeFrom(transform);
        _c_body->setWorldTransform(c_transform);
    }
}

// MARK: Force Accessors

- (PKVector3)linearVelocity {
    btVector3 c_velocity = _c_body->getLinearVelocity();
    return PKVector3Make(c_velocity.x(), c_velocity.y(), c_velocity.z());
}

- (void)setLinearVelocity:(PKVector3)linearVelocity {
    btVector3 c_velocity = btVector3(linearVelocity.x, linearVelocity.y, linearVelocity.z);
    _c_body->setLinearVelocity(c_velocity);
}

- (PKVector3)angularVelocity {
    btVector3 c_velocity = _c_body->getAngularVelocity();
    return PKVector3Make(c_velocity.x(), c_velocity.y(), c_velocity.z());
}

- (void)setAngularVelocity:(PKVector3)angularVelocity {
    btVector3 c_velocity = btVector3(angularVelocity.x, angularVelocity.y, angularVelocity.z);
    _c_body->setAngularVelocity(c_velocity);
}

- (PKVector3)linearVelocityFactor {
    btVector3 c_factor = _c_body->getLinearFactor();
    return PKVector3Make(c_factor.x(), c_factor.y(), c_factor.z());
}

- (void)setLinearVelocityFactor:(PKVector3)linearVelocityFactor {
    btVector3 c_factor = btVector3(linearVelocityFactor.x, linearVelocityFactor.y, linearVelocityFactor.z);
    _c_body->setLinearFactor(c_factor);
}

- (PKVector3)angularVelocityFactor {
    btVector3 c_factor = _c_body->getAngularFactor();
    return PKVector3Make(c_factor.x(), c_factor.y(), c_factor.z());
}

- (void)setAngularVelocityFactor:(PKVector3)angularVelocityFactor {
    btVector3 c_factor = btVector3(angularVelocityFactor.x, angularVelocityFactor.y, angularVelocityFactor.z);
    _c_body->setAngularFactor(c_factor);
}

- (float)friction {
    return _c_body->getFriction();
}

- (void)setFriction:(float)friction {
    _c_body->setFriction(friction);
}

- (float)rollingFriction {
    return _c_body->getRollingFriction();
}

- (void)setRollingFriction:(float)rollingFriction {
    _c_body->setRollingFriction(rollingFriction);
}

- (float)spinningFriction {
    return _c_body->getSpinningFriction();
}

- (void)setSpinningFriction:(float)spinningFriction {
    _c_body->setSpinningFriction(spinningFriction);
}

- (float)restitution {
    return _c_body->getRestitution();
}

- (void)setRestitution:(float)restitution {
    _c_body->setRestitution(restitution);
}

- (float)linearDamping {
    return _c_body->getLinearDamping();
}

- (void)setLinearDamping:(float)linearDamping {
    _c_body->setDamping(linearDamping, self.angularDamping);
}

- (float)angularDamping {
    return _c_body->getAngularDamping();
}

- (void)setAngularDamping:(float)angularDamping {
    _c_body->setDamping(self.linearDamping, angularDamping);
}

- (PKVector3)centerOfMass {
    btVector3 c_position = _c_body->getCenterOfMassPosition();
    return PKVector3Make(c_position.x(), c_position.y(), c_position.z());
}

- (void)setCenterOfMass:(PKVector3)centerOfMass {
    btTransform c_transform = _c_body->getCenterOfMassTransform();
    btVector3 c_position = btVector3(centerOfMass.x, centerOfMass.y, centerOfMass.z);
    c_transform.setOrigin(c_position);
    _c_body->setCenterOfMassTransform(c_transform);
}

- (float)linearSleepingThreshold {
    return _c_body->getLinearSleepingThreshold();
}

- (void)setLinearSleepingThreshold:(float)linearSleepingThreshold {
    _c_body->setSleepingThresholds(linearSleepingThreshold, self.angularSleepingThreshold);
}

- (float)angularSleepingThreshold {
    return _c_body->getAngularSleepingThreshold();
}

- (void)setAngularSleepingThreshold:(float)angularSleepingThreshold {
    _c_body->setSleepingThresholds(self.linearSleepingThreshold, angularSleepingThreshold);
}

- (BOOL)isCollisionEnabled {
    return !(_c_body->getCollisionFlags() & btCollisionObject::CF_NO_CONTACT_RESPONSE);
}

- (void)setIsCollisionEnabled:(BOOL)isCollisionEnabled {
    if (isCollisionEnabled) {
        _c_body->setCollisionFlags(_c_body->getCollisionFlags() & ~btCollisionObject::CF_NO_CONTACT_RESPONSE);
    } else {
        _c_body->setCollisionFlags(_c_body->getCollisionFlags() | btCollisionObject::CF_NO_CONTACT_RESPONSE);
    }
}

- (BOOL)isSleepingEnabled {
    return _c_body->getActivationState() != DISABLE_DEACTIVATION;
}

- (void)setIsSleepingEnabled:(BOOL)isSleepingEnabled {
    if (isSleepingEnabled) {
        _c_body->setActivationState(ACTIVE_TAG);
    } else {
        _c_body->setActivationState(DISABLE_DEACTIVATION);
    }
}

- (BOOL)isForcesEnabled {
    return _c_body->getActivationState() != DISABLE_SIMULATION;
}

- (void)setIsForcesEnabled:(BOOL)isForcesEnabled {
    if (isForcesEnabled) {
        _c_body->setActivationState(ACTIVE_TAG);
    } else {
        _c_body->setActivationState(DISABLE_SIMULATION);
    }
}

// MARK: Forces

- (void)clearForces {
    self.linearVelocity = PKVector3Make(0,0,0);
    self.angularVelocity = PKVector3Make(0,0,0);
    _c_body->clearGravity();
    _c_body->clearForces();
}

- (void)applyForce: (PKVector3)force impulse: (BOOL)impulse {
    btVector3 c_force = btVector3(force.x, force.y, force.z);
    btVector3 c_position = btVector3(0, 0, 0);
    _c_body->activate(true);
    if (impulse) {
        _c_body->applyImpulse(c_force, c_position);
    } else {
        _c_body->applyForce(c_force, c_position);
    }
}

- (void)applyTorque: (PKVector3)torque impulse: (BOOL)impulse {
    _c_body->activate(true);
    btVector3 c_torque = btVector3(torque.x, torque.y, torque.z);
    if (impulse) {
        _c_body->applyTorqueImpulse(c_torque);
    } else {
        _c_body->applyTorque(c_torque);
    }
}

- (void)setContinuousCollisionDetectionRadius:(float)continuousCollisionDetectionRadius {
    _continuousCollisionDetectionRadius = continuousCollisionDetectionRadius;
    if (_continuousCollisionDetectionRadius > 0) {
        _c_body->setCcdMotionThreshold(0.0000001);
        _c_body->setCcdSweptSphereRadius(_continuousCollisionDetectionRadius);
    } else {
        _c_body->setCcdMotionThreshold(FLT_MAX);
        _c_body->setCcdSweptSphereRadius(0);
    }
}

@end
