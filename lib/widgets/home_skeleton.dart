import 'package:flutter/material.dart';
import 'shimmer_effect.dart';

class HomeSkeleton extends StatelessWidget {
  final bool isDesktop;

  const HomeSkeleton({Key? key, required this.isDesktop}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 32.0 : 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSkeleton(),
            SizedBox(height: isDesktop ? 40 : 30),
            _buildStatsSkeleton(),
            SizedBox(height: isDesktop ? 40 : 30),
            _buildFeatureGridSkeleton(),
            SizedBox(height: isDesktop ? 40 : 30),
            _buildProgressSkeleton(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerEffect(
          child: Container(
            width: 100,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        SizedBox(height: 8),
        ShimmerEffect(
          child: Container(
            width: 200,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        SizedBox(height: 8),
        ShimmerEffect(
          child: Container(
            width: 150,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSkeleton() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItemSkeleton(),
          _buildStatDivider(),
          _buildStatItemSkeleton(),
          _buildStatDivider(),
          _buildStatItemSkeleton(),
        ],
      ),
    );
  }

  Widget _buildStatItemSkeleton() {
    return Column(
      children: [
        ShimmerEffect(
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
          ),
        ),
        SizedBox(height: 8),
        ShimmerEffect(
          child: Container(
            width: 40,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        SizedBox(height: 4),
        ShimmerEffect(
          child: Container(
            width: 60,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withOpacity(0.1),
    );
  }

  Widget _buildFeatureGridSkeleton() {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 3 : 2,
        childAspectRatio: isDesktop ? 1.1 : 1.2,
        crossAxisSpacing: isDesktop ? 24.0 : 16.0,
        mainAxisSpacing: isDesktop ? 24.0 : 16.0,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return ShimmerEffect(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerEffect(
          child: Container(
            width: 150,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        SizedBox(height: 24),
        ...List.generate(2, (index) => _buildProgressCardSkeleton()),
      ],
    );
  }

  Widget _buildProgressCardSkeleton() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: ShimmerEffect(
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

