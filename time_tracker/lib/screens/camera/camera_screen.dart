// Replace the bottom Positioned widget's child Column with:
Positioned(
  bottom: 0, left: 0, right: 0,
  child: Container(
    padding: EdgeInsets.only(
      bottom: MediaQuery.of(context).padding.bottom + 24,
      top: 24,
    ),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Colors.black.withOpacity(0.8),
          Colors.transparent,
        ],
      ),
    ),
    child: Column(
      children: [
        // Shutter
        Center(
          child: GestureDetector(
            onTap: _isCapturing ? null : _capture,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: _isCapturing ? 64 : 72,
              height: _isCapturing ? 64 : 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _modeColor, width: 4),
              ),
              child: Center(
                child: _isCapturing
                    ? const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)
                    : Container(
                        margin: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _modeColor,
                        ),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Skip button
        TextButton(
          onPressed: () => Navigator.pop(context, 'skip'),
          child: const Text(
            'Skip Photo',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              decoration: TextDecoration.underline,
              decorationColor: Colors.white70,
            ),
          ),
        ),
      ],
    ),
  ),
),