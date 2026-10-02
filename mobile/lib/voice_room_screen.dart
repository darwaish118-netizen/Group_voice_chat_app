import 'package:flutter/material.dart';

class VoiceRoomScreen extends StatelessWidget {
  final String roomId;
  final String roomName;
  final int seatCount;

  const VoiceRoomScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    this.seatCount = 5,
  });

  int get validSeatCount {
    if (seatCount == 5 ||
        seatCount == 10 ||
        seatCount == 15 ||
        seatCount == 20 ||
        seatCount == 25) {
      return seatCount;
    }

    return 5;
  }

  @override
  Widget build(BuildContext context) {
    final int seats = validSeatCount;

    return Scaffold(
      backgroundColor: const Color(0xFF17132B),

      appBar: AppBar(
        backgroundColor: const Color(0xFF211A3A),
        foregroundColor: Colors.white,
        titleSpacing: 12,

        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              roomName,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Room ID: $roomId',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              _showRoomMenu(context);
            },
          ),
        ],
      ),

      body: Column(
        children: [
          const SizedBox(height: 18),

          const Text(
            'Voice Room',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            '$seats Seats',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: seats,

              gridDelegate:
                  SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _getCrossAxisCount(seats),
                mainAxisSpacing: 18,
                crossAxisSpacing: 18,
                childAspectRatio: 0.9,
              ),

              itemBuilder: (context, index) {
                return _Seat(
                  seatNumber: index + 1,
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              20,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF211A3A),
            ),

            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BottomButton(
                  icon: Icons.mic_off,
                  label: 'Mic',
                  onTap: () {
                    _showMessage(
                      context,
                      'Mic button pressed',
                    );
                  },
                ),

                _BottomButton(
                  icon: Icons.card_giftcard,
                  label: 'Gift',
                  onTap: () {
                    _showMessage(
                      context,
                      'Gift button pressed',
                    );
                  },
                ),

                _BottomButton(
                  icon: Icons.chat,
                  label: 'Chat',
                  onTap: () {
                    _showMessage(
                      context,
                      'Chat button pressed',
                    );
                  },
                ),

                _BottomButton(
                  icon: Icons.exit_to_app,
                  label: 'Exit',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getCrossAxisCount(int seats) {
    if (seats <= 5) {
      return 1;
    }

    if (seats <= 10) {
      return 2;
    }

    return 3;
  }

  void _showRoomMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF211A3A),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.lock,
                  color: Colors.white,
                ),
                title: const Text(
                  'Room Settings',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                },
              ),

              ListTile(
                leading: const Icon(
                  Icons.report,
                  color: Colors.white,
                ),
                title: const Text(
                  'Report Room',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                },
              ),

              ListTile(
                leading: const Icon(
                  Icons.close,
                  color: Colors.white,
                ),
                title: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMessage(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

class _Seat extends StatelessWidget {
  final int seatNumber;

  const _Seat({
    required this.seatNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF30284D),
            border: Border.all(
              color: Colors.white24,
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.person,
            color: Colors.white54,
            size: 34,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Seat $seatNumber',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _BottomButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BottomButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 26,
          ),

          const SizedBox(height: 5),

          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
