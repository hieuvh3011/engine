// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.12
part of engine;

/// A tree which stores a set of intervals that can be queried for intersection.
class IntervalTree<T> {
  /// The root node of the interval tree.
  final IntervalTreeNode<T> root;

  IntervalTree._(this.root);

  /// Creates an interval tree from a mapping of [T] values to a list of ranges.
  ///
  /// When the interval tree is queried, it will return a list of [T]s which
  /// have a range which contains the point.
  factory IntervalTree.createFromRanges(Map<T, List<CodeunitRange>> rangesMap) {
    // Get a list of all the ranges ordered by start index.
    final List<IntervalTreeNode<T>> intervals = <IntervalTreeNode<T>>[];
    rangesMap.forEach((T key, List<CodeunitRange> rangeList) {
      for (CodeunitRange range in rangeList) {
        intervals.add(IntervalTreeNode<T>(key, range.start, range.end));
      }
    });

    intervals
        .sort((IntervalTreeNode<T> a, IntervalTreeNode<T> b) => a.low - b.low);

    // Make a balanced binary search tree from the nodes sorted by low value.
    IntervalTreeNode<T>? _makeBalancedTree(List<IntervalTreeNode<T>> nodes) {
      if (nodes.length == 0) {
        return null;
      }
      if (nodes.length == 1) {
        return nodes.single;
      }
      int mid = nodes.length ~/ 2;
      IntervalTreeNode<T> root = nodes[mid];
      root.left = _makeBalancedTree(nodes.sublist(0, mid));
      root.right = _makeBalancedTree(nodes.sublist(mid + 1));
      return root;
    }

    // Given a node, computes the highest `high` point of all of the subnodes.
    //
    // As a side effect, this also computes the high point of all subnodes.
    void _computeHigh(IntervalTreeNode<T> root) {
      if (root.left == null && root.right == null) {
        root.computedHigh = root.high;
      } else if (root.left == null) {
        _computeHigh(root.right!);
        root.computedHigh = math.max(root.high, root.right!.computedHigh);
      } else if (root.right == null) {
        _computeHigh(root.left!);
        root.computedHigh = math.max(root.high, root.left!.computedHigh);
      } else {
        _computeHigh(root.right!);
        _computeHigh(root.left!);
        root.computedHigh = math.max(
            root.high,
            math.max(
              root.left!.computedHigh,
              root.right!.computedHigh,
            ));
      }
    }

    IntervalTreeNode<T> root = _makeBalancedTree(intervals)!;
    _computeHigh(root);

    return IntervalTree._(root);
  }

  /// Returns the list of objects which have been associated with intervals that
  /// intersect with [x].
  List<T> intersections(int x) {
    List<T> results = <T>[];
    root.searchForPoint(x, results);
    return results;
  }
}

class IntervalTreeNode<T> {
  final T value;
  final int low;
  final int high;
  int computedHigh;

  IntervalTreeNode<T>? left;
  IntervalTreeNode<T>? right;

  IntervalTreeNode(this.value, this.low, this.high) : computedHigh = high;

  Iterable<T> enumerateAllElements() sync* {
    if (left != null) {
      yield* left!.enumerateAllElements();
    }
    yield value;
    if (right != null) {
      yield* right!.enumerateAllElements();
    }
  }

  bool contains(int x) {
    return low <= x && x <= high;
  }

  // Searches the tree rooted at this node for all T containing [x].
  void searchForPoint(int x, List<T> result) {
    if (x > computedHigh) {
      return;
    }
    left?.searchForPoint(x, result);
    if (this.contains(x)) {
      result.add(value);
    }
    if (x < low) {
      return;
    }
    right?.searchForPoint(x, result);
  }
}
