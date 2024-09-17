import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const ShinjukuStationGame());
}

class ShinjukuStationGame extends StatelessWidget {
  const ShinjukuStationGame({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '新宿駅ゲーム',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  GameScreenState createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  static const int numLanes = 3;
  int playerLane = 1; // 主人公の位置（0: 左, 1: 中央, 2: 右）
  List<Obstacle> obstacles = [];
  Random random = Random();
  bool isGameOver = false;
  late AnimationController _controller;
  late Timer _obstacleTimer;

  // 調整可能な変数
  double obstacleGenerationInterval = 1.5; // 障害物の生成間隔（秒）
  double playerReactionTime = 1.2; // プレイヤーが反応できる時間（秒）

  static const double playerHeight = 80;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16), // 約60fps
    )..addListener(_updateGame);

    _controller.repeat();

    _obstacleTimer = Timer.periodic(
        Duration(milliseconds: (obstacleGenerationInterval * 1000).toInt()),
        (timer) {
      if (!isGameOver) {
        _generateObstacle();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _obstacleTimer.cancel();
    super.dispose();
  }

  void _updateGame() {
    if (isGameOver) return;

    setState(() {
      for (var obstacle in obstacles) {
        obstacle.update();
      }

      // 画面外の障害物を削除
      obstacles.removeWhere((obstacle) => obstacle.isOffScreen(context));

      // コリジョンのチェック
      _checkCollisions();
    });
  }

  void _generateObstacle() {
    // 生成する障害物のタイプをランダムに決定
    int obstacleType =
        random.nextInt(4); // 0: JK, 1: オタク, 2: おじさん, 3: キャリアウーマン

    Obstacle? obstacle;

    // 障害物のインスタンスを生成
    if (obstacleType == 0) {
      obstacle = JK();
    } else if (obstacleType == 1) {
      obstacle = Otaku();
    } else if (obstacleType == 2) {
      obstacle = Ojisan();
    } else if (obstacleType == 3) {
      obstacle = CareerWoman();
    }

    if (obstacle != null) {
      // 障害物が必要とするレーンを取得
      List<int> requiredLanes = List<int>.generate(numLanes, (index) => index);

      // 障害物が配置可能なレーンを取得
      List<int> availableLanes = requiredLanes.toList();

      // 他の障害物との位置関係をチェック
      for (var obs in obstacles) {
        if (obs.isInFutureCollisionCourse(obstacle, playerReactionTime)) {
          // 将来的に衝突の可能性があるレーンを除外
          if (obs is CareerWoman) {
            availableLanes.remove(obs.lane);
            availableLanes.remove(obs.lane + 1);
          } else {
            availableLanes.remove(obs.lane);
          }
        }
      }

      // 障害物が必要とするレーンが空いているか確認
      List<int> obstacleRequiredLanes = obstacle.getRequiredLanes();
      List<int> possibleLanes = [];
      for (int lane in availableLanes) {
        bool canPlace = obstacleRequiredLanes.every((requiredLane) {
          int targetLane = lane + requiredLane - obstacleRequiredLanes.first;
          return availableLanes.contains(targetLane) &&
              targetLane >= 0 &&
              targetLane < numLanes;
        });
        if (canPlace) {
          possibleLanes.add(lane);
        }
      }

      if (possibleLanes.isNotEmpty) {
        // ランダムな位置に配置
        obstacle.lane = possibleLanes[random.nextInt(possibleLanes.length)];

        // おじさんの移動先を主人公の現在のレーンに設定
        if (obstacle is Ojisan) {
          obstacle.targetLane = playerLane;
        }

        obstacles.add(obstacle);
      }
    }
  }

  void _checkCollisions() {
    for (var obstacle in obstacles) {
      if (obstacle.collidesWith(playerLane, context)) {
        isGameOver = true;
        _controller.stop();
        _showGameOverDialog();
        break;
      }
    }
  }

  void _onSwipe(DragEndDetails details) {
    if (details.primaryVelocity == null || isGameOver) return;

    setState(() {
      if (details.primaryVelocity! < 0) {
        // 左スワイプ
        if (playerLane > 0) playerLane--;
      } else {
        // 右スワイプ
        if (playerLane < numLanes - 1) playerLane++;
      }
    });
  }

  void _restartGame() {
    setState(() {
      playerLane = 1;
      obstacles.clear();
      isGameOver = false;
      _controller.repeat();
    });
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ゲームオーバー'),
        content: const Text('残念、ぶつかってしまいました！もう一度やりますか？'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _restartGame();
            },
            child: const Text('再挑戦'),
          ),
        ],
      ),
    );
  }

  // プレイヤーのY座標を計算するゲッター
  double get playerY {
    double screenHeight = MediaQuery.of(context).size.height;
    return screenHeight - 20 - playerHeight;
  }

  @override
  Widget build(BuildContext context) {
    double laneWidth = MediaQuery.of(context).size.width / numLanes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('新宿駅ゲーム'),
      ),
      body: GestureDetector(
        onHorizontalDragEnd: _onSwipe,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(color: Colors.grey[200]),
            ),
            // 障害物
            ...obstacles.map((obstacle) {
              return Positioned(
                top: obstacle.yPosition,
                left: laneWidth * obstacle.lane,
                child: obstacle.build(context, laneWidth),
              );
            }).toList(),
            // 主人公
            Positioned(
              bottom: 20,
              left: laneWidth * playerLane,
              child: Player(laneWidth: laneWidth),
            ),
          ],
        ),
      ),
    );
  }
}

class Player extends StatelessWidget {
  final double laneWidth;
  const Player({Key? key, required this.laneWidth}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 主人公のウィジェット（サイズを調整）
    return Container(
      width: laneWidth,
      height: GameScreenState.playerHeight,
      color: Colors.blue,
      child: const Center(
        child: Text('あなた', style: TextStyle(color: Colors.white, fontSize: 20)),
      ),
    );
  }
}

abstract class Obstacle {
  static const double baseSpeed = 2.0;
  int lane = 0;
  double yPosition;
  double speed;
  Obstacle({this.yPosition = -100, this.speed = baseSpeed});

  void update() {
    yPosition += speed;
  }

  bool isOffScreen(BuildContext context) {
    return yPosition > MediaQuery.of(context).size.height;
  }

  bool collidesWith(int playerLane, BuildContext context) {
    double laneWidth =
        MediaQuery.of(context).size.width / GameScreenState.numLanes;

    Rect playerRect = Rect.fromLTWH(
      playerLane * laneWidth,
      (context.findAncestorStateOfType<GameScreenState>()!).playerY,
      laneWidth,
      GameScreenState.playerHeight,
    );

    Rect obstacleRect = Rect.fromLTWH(
      lane * laneWidth,
      yPosition,
      getWidth(context),
      getHeight(),
    );

    // 当たり判定
    return playerRect.overlaps(obstacleRect);
  }

  bool isInFutureCollisionCourse(Obstacle obstacle, double reactionTime) {
    double thisBottomY = yPosition + getHeight();
    double obstacleBottomY = obstacle.yPosition + obstacle.getHeight();

    // この障害物がプレイヤーに到達するまでの時間
    double timeToPlayer =
        ((context.findAncestorStateOfType<GameScreenState>()!).playerY -
                thisBottomY) /
            speed;

    // 比較対象の障害物がプレイヤーに到達するまでの時間
    double obstacleTimeToPlayer =
        ((context.findAncestorStateOfType<GameScreenState>()!).playerY -
                obstacleBottomY) /
            obstacle.speed;

    // プレイヤーの反応時間を考慮して、将来的に同じレーンにいるかどうかを判断
    return (timeToPlayer - obstacleTimeToPlayer).abs() < reactionTime &&
        lane == obstacle.lane;
  }

  Widget build(BuildContext context, double laneWidth);

  List<int> getRequiredLanes();

  double getWidth(BuildContext context) {
    return laneWidth(context) * getRequiredLanes().length;
  }

  double laneWidth(BuildContext context) {
    return MediaQuery.of(context).size.width / GameScreenState.numLanes;
  }

  double getHeight() {
    return 100; // 障害物の高さ
  }
}

class JK extends Obstacle {
  JK() : super();

  @override
  Widget build(BuildContext context, double laneWidth) {
    return Container(
      width: getWidth(context),
      height: getHeight(),
      color: Colors.pink,
      child: const Center(
        child: Text('JK', style: TextStyle(color: Colors.white, fontSize: 24)),
      ),
    );
  }

  @override
  List<int> getRequiredLanes() {
    return [lane];
  }
}

class Otaku extends Obstacle {
  Otaku() : super(speed: 3.0);

  @override
  void update() {
    super.update();
  }

  @override
  Widget build(BuildContext context, double laneWidth) {
    return Container(
      width: getWidth(context),
      height: getHeight(),
      color: Colors.green,
      child: const Center(
        child: Text('オタク', style: TextStyle(color: Colors.white, fontSize: 20)),
      ),
    );
  }

  @override
  List<int> getRequiredLanes() {
    return [lane];
  }
}

class Ojisan extends Obstacle {
  bool hasMoved = false;
  int targetLane = 0;

  Ojisan() : super();

  @override
  void update() {
    super.update();
    if (!hasMoved && yPosition > 200) {
      // 主人公のレーンに移動
      lane = targetLane;
      hasMoved = true;
    }
  }

  @override
  Widget build(BuildContext context, double laneWidth) {
    return Container(
      width: getWidth(context),
      height: getHeight(),
      color: Colors.brown,
      child: const Center(
        child: Text('おじさん', style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
    );
  }

  @override
  List<int> getRequiredLanes() {
    return [lane];
  }
}

class CareerWoman extends Obstacle {
  CareerWoman() : super();

  @override
  Widget build(BuildContext context, double laneWidth) {
    return Container(
      width: getWidth(context),
      height: getHeight(),
      color: Colors.purple,
      child: const Center(
        child:
            Text('キャリアウーマン', style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
    );
  }

  @override
  List<int> getRequiredLanes() {
    return [lane, lane + 1];
  }
}
