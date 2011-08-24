package {
	import awayphysics.dynamics.AWPRigidBody;
	import awayphysics.collision.shapes.AWPBvhTriangleMeshShape;
	import awayphysics.data.AWPCollisionFlags;
	import awayphysics.plugin.away3d.Away3DMesh;
	import awayphysics.collision.dispatch.AWPGhostObject;
	import awayphysics.collision.shapes.AWPCapsuleShape;
	import awayphysics.dynamics.character.AWPKinematicCharacterController;
	import awayphysics.dynamics.AWPDynamicsWorld;

	import away3d.containers.ObjectContainer3D;
	import away3d.containers.View3D;
	import away3d.debug.AwayStats;
	import away3d.entities.Mesh;
	import away3d.lights.PointLight;
	import away3d.materials.ColorMaterial;
	import away3d.materials.BitmapMaterial;
	import away3d.events.LoaderEvent;
	import away3d.events.AssetEvent;
	import away3d.loaders.Loader3D;
	import away3d.loaders.parsers.OBJParser;
	import away3d.loaders.parsers.MD5AnimParser;
	import away3d.loaders.parsers.MD5MeshParser;
	import away3d.library.assets.AssetType;
	import away3d.library.AssetLibrary;
	import away3d.animators.SmoothSkeletonAnimator;
	import away3d.animators.data.SkeletonAnimationSequence;
	import away3d.animators.data.SkeletonAnimationState;

	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.geom.Matrix3D;
	import flash.geom.Vector3D;
	import flash.net.URLRequest;
	import flash.ui.Keyboard;

	public class CharacterDemo extends Sprite {
		[Embed(source="../embeds/hellknight/hellknight.jpg")]
		private var Skin : Class;
		[Embed(source="../embeds/hellknight/hellknight_s.png")]
		private var Spec : Class;
		[Embed(source="../embeds/hellknight/hellknight_local.png")]
		private var Norm : Class;
		private var _view : View3D;
		private var _light : PointLight;
		private var _animationController : SmoothSkeletonAnimator;
		private var physicsWorld : AWPDynamicsWorld;
		private var character : AWPKinematicCharacterController;
		private var timeStep : Number = 1.0 / 60;
		private var keyRight : Boolean = false;
		private var keyLeft : Boolean = false;
		private var keyForward : Boolean = false;
		private var keyReverse : Boolean = false;
		private var keyUp : Boolean = false;
		private var walkDirection : Vector3D = new Vector3D();
		private var walkSpeed : Number = 10;
		private var chRotation : Number = 0;

		public function CharacterDemo() {
			if (stage) init();
			else addEventListener(Event.ADDED_TO_STAGE, init);
		}

		private function init(e : Event = null) : void {
			removeEventListener(Event.ADDED_TO_STAGE, init);

			_view = new View3D();
			this.addChild(_view);
			this.addChild(new AwayStats(_view));

			_light = new PointLight();
			_light.y = 5000;
			_view.scene.addChild(_light);

			_view.camera.lens.far = 20000;
			_view.camera.y = _light.y;
			_view.camera.z = _light.z;
			_view.camera.rotationX = 25;
			_view.antiAlias = 4;

			// init the physics world
			physicsWorld = AWPDynamicsWorld.getInstance();
			physicsWorld.initWithDbvtBroadphase();

			// load scene model
			var _loader : Loader3D = new Loader3D();
			_loader.load(new URLRequest('assets/scene.obj'), new OBJParser());
			_loader.addEventListener(LoaderEvent.RESOURCE_COMPLETE, onSceneResourceComplete);

			// load character mesh
			AssetLibrary.enableParser(MD5MeshParser);
			AssetLibrary.enableParser(MD5AnimParser);
			_loader = new Loader3D();
			_loader.addEventListener(AssetEvent.ASSET_COMPLETE, onMeshComplete);
			_loader.load(new URLRequest("assets/hellknight/hellknight.md5mesh"));

			stage.addEventListener(KeyboardEvent.KEY_DOWN, keyDownHandler);
			stage.addEventListener(KeyboardEvent.KEY_UP, keyUpHandler);
			stage.addEventListener(Event.ENTER_FRAME, handleEnterFrame);
		}

		private function onMeshComplete(event : AssetEvent) : void {
			if (event.asset.assetType == AssetType.MESH) {
				var mesh : Mesh = event.asset as Mesh;
				mesh.scale(6);
				_view.scene.addChild(mesh);

				_animationController = new SmoothSkeletonAnimator(SkeletonAnimationState(mesh.animationState));

				var material : BitmapMaterial = new BitmapMaterial(new Skin().bitmapData);
				material.lights = [_light];
				material.normalMap = new Norm().bitmapData;
				material.specularMap = new Spec().bitmapData;
				mesh.material = material;

				// create character shape and controller
				var shape : AWPCapsuleShape = new AWPCapsuleShape(200, 50);
				var ghostObject : AWPGhostObject = new AWPGhostObject(shape, new Away3DMesh(mesh));
				ghostObject.collisionFlags = AWPCollisionFlags.CF_CHARACTER_OBJECT;
				character = new AWPKinematicCharacterController(ghostObject, shape, 0.1);
				physicsWorld.addCharacter(character);
				character.warp(new Vector3D(0, 500, -1000));

				AssetLibrary.addEventListener(AssetEvent.ASSET_COMPLETE, onAnimationComplete);
				AssetLibrary.load(new URLRequest("assets/hellknight/idle2.md5anim"), null, null, "idle");
				AssetLibrary.load(new URLRequest("assets/hellknight/walk7.md5anim"), null, null, "walk");
			}
		}

		private function onAnimationComplete(event : AssetEvent) : void {
			var seq : SkeletonAnimationSequence = event.asset as SkeletonAnimationSequence;
			if (seq!==null) {
				seq.name = event.asset.assetNamespace;
				_animationController.addSequence(seq);
				if (seq.name == "idle")
					_animationController.play("idle", 0.5);
			}
		}

		private function onSceneResourceComplete(event : LoaderEvent) : void {
			var container : ObjectContainer3D = ObjectContainer3D(event.target);
			_view.scene.addChild(container);

			var materia : ColorMaterial = new ColorMaterial(0xfa6c16);
			materia.lights = [_light];
			var sceneMesh : Mesh = Mesh(container.getChildAt(0));
			sceneMesh.geometry.scale(1000);
			sceneMesh.material = materia;

			// create triangle mesh shape
			var sceneSkin : Away3DMesh = new Away3DMesh(sceneMesh);
			var sceneShape : AWPBvhTriangleMeshShape = new AWPBvhTriangleMeshShape(sceneSkin);
			var sceneBody : AWPRigidBody = new AWPRigidBody(sceneShape, sceneSkin, 0);
			physicsWorld.addRigidBody(sceneBody);

			/*
			var material:ColorMaterial = new ColorMaterial(0xffff00);
			material.lights = [_light];
			
			// create rigidbody shape
			var boxShape:AWPBoxShape = new AWPBoxShape(200, 200, 200);
			
			// create rigidbodies
			var mesh:Mesh;
			var body:AWPRigidBody;
			var numx:int = 10;
			var numy:int = 5;
			var numz:int = 1;
			for (var i:int = 0; i < numx; i++ ) {
			for (var j:int = 0; j < numz; j++ ) {
			for (var k:int = 0; k < numy; k++ ) {
			// create boxes
			mesh = new Cube(material, 200, 200, 200);
			_view.scene.addChild(mesh);
			body = new AWPRigidBody(boxShape, new Away3DMesh(mesh), 1);
			body.friction = .9;
			body.position = new Vector3D( -1500 + i * 200, 200 + k * 200, 1000+j * 200);
			physicsWorld.addRigidBody(body);
			}
			}
			}*/
		}

		private function keyDownHandler(event : KeyboardEvent) : void {
			switch(event.keyCode) {
				case Keyboard.UP:
					keyForward = true;
					keyReverse = false;
					break;
				case Keyboard.DOWN:
					keyReverse = true;
					keyForward = false;
					break;
				case Keyboard.LEFT:
					keyLeft = true;
					keyRight = false;
					break;
				case Keyboard.RIGHT:
					keyRight = true;
					keyLeft = false;
					break;
				case Keyboard.SPACE:
					keyUp = true;
					break;
			}
		}

		private function keyUpHandler(event : KeyboardEvent) : void {
			switch(event.keyCode) {
				case Keyboard.UP:
					keyForward = false;
					walkDirection.scaleBy(0);
					character.setWalkDirection(walkDirection);
					_animationController.play("idle", 0.5);
					break;
				case Keyboard.DOWN:
					keyReverse = false;
					walkDirection.scaleBy(0);
					character.setWalkDirection(walkDirection);
					_animationController.play("idle", 0.5);
					break;
				case Keyboard.LEFT:
					keyLeft = false;
					break;
				case Keyboard.RIGHT:
					keyRight = false;
					break;
				case Keyboard.SPACE:
					keyUp = false;
					break;
			}
		}

		private function handleEnterFrame(e : Event) : void {
			if (character) {
				var rot : Matrix3D = new Matrix3D();
				if (keyLeft && character.onGround()) {
					chRotation -= 3;
					rot.appendRotation(chRotation, new Vector3D(0, 1, 0));
					character.ghostObject.rotation = rot;
				}
				if (keyRight && character.onGround()) {
					chRotation += 3;
					rot.appendRotation(chRotation, new Vector3D(0, 1, 0));
					character.ghostObject.rotation = rot;
				}
				if (keyForward) {
					if (walkDirection.length == 0) {
						_animationController.play("walk", 0.5);
						_animationController.timeScale = 1.2;
					}
					character.ghostObject.rotation.copyRowTo(2, walkDirection);
					walkDirection.scaleBy(-walkSpeed);
					character.setWalkDirection(walkDirection);
				}
				if (keyReverse) {
					if (walkDirection.length == 0) {
						_animationController.play("walk", 0.5);
						_animationController.timeScale = -1.2;
					}
					character.ghostObject.rotation.copyRowTo(2, walkDirection);
					walkDirection.scaleBy(walkSpeed);
					character.setWalkDirection(walkDirection);
				}
				if (keyUp && character.onGround()) {
					character.jump();
				}
				_view.camera.position = character.ghostObject.position.add(new Vector3D(0, 2000, -2500));
				_view.camera.lookAt(character.ghostObject.position);
			}

			physicsWorld.step(timeStep);
			_view.render();
		}
	}
}