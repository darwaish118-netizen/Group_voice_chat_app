import 'package:flutter/material.dart';

class VoiceRoomScreen extends StatelessWidget {
  final String roomName;
  final int seatCount;

  const VoiceRoomScreen({
    super.key,
    required this.roomName,
    required this.seatCount,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF17132B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF211A3A),
        foregroundColor: Colors.white,
        title: Text(roomName),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),

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
            '$seatCount Seats',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 25),

          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: seatCount,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: seatCount <= 5
                    ? 1
                    : seatCount <= 10
                        ? 2
                        : 3,
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
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF211A3A),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BottomButton(
                  icon: Icons.mic_off,
                  label: 'Mic',
                  onTap: () {},
                ),
                _BottomButton(
                  icon: Icons.card_giftcard,
                  label: 'Gift',
                  onTap: () {},
                ),
                _BottomButton(
                  icon: Icons.chat,
                  label: 'Chat',
                  onTap: () {},
                ),
                _BottomButton(
                  icon: Icons.exit_to_app,
                  label: 'Exit',
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ],
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
