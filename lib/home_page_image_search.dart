part of 'home_page.dart';

extension HomePageImageSearch on _HomePageState {
  // =========================================================
  // CAMERA / GALLERY IMAGE SEARCH
  // =========================================================

  Future<void> _openCameraSearch() async {
    final ImageSource? source =
        await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor:
          Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              20,
            ),
            decoration:
                const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin:
                      const EdgeInsets.only(
                    bottom: 18,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.grey.shade300,
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                  ),
                ),
                const Align(
                  alignment:
                      Alignment.centerLeft,
                  child: Text(
                    'Search by Image',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 16,
                ),
                ListTile(
                  contentPadding:
                      EdgeInsets.zero,
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration:
                        BoxDecoration(
                      color: Colors
                          .redAccent
                          .withValues(
                        alpha: 0.10,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        14,
                      ),
                    ),
                    child: const Icon(
                      Icons
                          .camera_alt_outlined,
                      color:
                          Colors.redAccent,
                    ),
                  ),
                  title: const Text(
                    'Take Photo',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    'Take a new picture with camera',
                  ),
                  onTap: () {
                    Navigator.pop(
                      context,
                      ImageSource.camera,
                    );
                  },
                ),
                const SizedBox(height: 6),
                ListTile(
                  contentPadding:
                      EdgeInsets.zero,
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration:
                        BoxDecoration(
                      color: Colors
                          .blueAccent
                          .withValues(
                        alpha: 0.10,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        14,
                      ),
                    ),
                    child: const Icon(
                      Icons
                          .photo_library_outlined,
                      color:
                          Colors.blueAccent,
                    ),
                  ),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    'Select an existing product photo',
                  ),
                  onTap: () {
                    Navigator.pop(
                      context,
                      ImageSource.gallery,
                    );
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width:
                      double.infinity,
                  height: 46,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                      );
                    },
                    child:
                        const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null || !mounted) {
      return;
    }

    try {
      final picker =
          ImagePicker();

      final XFile? image =
          await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (image == null || !mounted) {
        return;
      }

      await _showImagePreview(image);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not select image: $e',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    }
  }

  // =========================================================
  // IMAGE PREVIEW
  // =========================================================

  Future<void> _showImagePreview(
    XFile image,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            padding:
                const EdgeInsets.all(16),
            decoration:
                const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin:
                      const EdgeInsets.only(
                    bottom: 16,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.grey.shade300,
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                  ),
                ),
                const Align(
                  alignment:
                      Alignment.centerLeft,
                  child: Text(
                    'Selected Photo',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                  child: Image.file(
                    File(image.path),
                    width:
                        double.infinity,
                    height: 300,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(
                  height: 16,
                ),
                Row(
                  children: [
                    Expanded(
                      child:
                          OutlinedButton
                              .icon(
                        style:
                            OutlinedButton
                                .styleFrom(
                          minimumSize:
                              const Size
                                  .fromHeight(
                            50,
                          ),
                          side:
                              const BorderSide(
                            color:
                                Colors.redAccent,
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              14,
                            ),
                          ),
                        ),
                        onPressed:
                            () async {
                          Navigator.pop(
                            context,
                          );
                          await _openCameraSearch();
                        },
                        icon:
                            const Icon(
                          Icons.refresh,
                          color:
                              Colors.redAccent,
                        ),
                        label:
                            const Text(
                          'Choose Again',
                          style:
                              TextStyle(
                            color:
                                Colors.redAccent,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child:
                          ElevatedButton
                              .icon(
                        style:
                            ElevatedButton
                                .styleFrom(
                          backgroundColor:
                              Colors.redAccent,
                          foregroundColor:
                              Colors.white,
                          minimumSize:
                              const Size
                                  .fromHeight(
                            50,
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              14,
                            ),
                          ),
                        ),
                        onPressed:
                            () async {
                          Navigator.pop(
                            context,
                          );
                          await _findProductsFromImage(
                            image,
                          );
                        },
                        icon:
                            const Icon(
                          Icons.search,
                        ),
                        label:
                            const Text(
                          'Use Photo',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 8,
                ),
                SizedBox(
                  width:
                      double.infinity,
                  height: 45,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                      );
                    },
                    child:
                        const Text(
                      'Cancel',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // IMAGE ANALYSIS
  // =========================================================

  Future<void> _findProductsFromImage(
    XFile image,
  ) async {
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 3,
                ),
              ),
              SizedBox(width: 18),
              Expanded(
                child: Text(
                  'Analyzing image...',
                ),
              ),
            ],
          ),
        );
      },
    );

    ImageLabeler? imageLabeler;

    try {
      final inputImage =
          InputImage.fromFilePath(
        image.path,
      );

      imageLabeler =
          ImageLabeler(
        options:
            ImageLabelerOptions(
          confidenceThreshold:
              0.45,
        ),
      );

      final labels =
          await imageLabeler.processImage(
        inputImage,
      );

      final detectedLabels =
          labels
              .map(
                (label) => label.label
                    .trim()
                    .toLowerCase(),
              )
              .where(
                (label) =>
                    label.isNotEmpty,
              )
              .toSet()
              .toList();

      final snapshot =
          await FirebaseFirestore
              .instance
              .collection('products')
              .get();

      final matchedProducts =
          <QueryDocumentSnapshot>[];

      for (final doc
          in snapshot.docs) {
        final data = doc.data();

        final productName =
            data['name']
                    ?.toString()
                    .toLowerCase() ??
                '';

        final category =
            data['category']
                    ?.toString()
                    .toLowerCase() ??
                '';

        final description =
            data['description']
                    ?.toString()
                    .toLowerCase() ??
                '';

        final searchText =
            '$productName $category $description';

        bool matched = false;

        for (final label
            in detectedLabels) {
          if (searchText
              .contains(label)) {
            matched = true;
            break;
          }

          final words = label
              .split(
                RegExp(
                  r'[\s\-_]+',
                ),
              )
              .where(
                (word) =>
                    word.length >= 3,
              );

          for (final word
              in words) {
            if (searchText
                .contains(word)) {
              matched = true;
              break;
            }
          }

          if (matched) {
            break;
          }
        }

        if (matched) {
          matchedProducts.add(doc);
        }
      }

      if (!mounted) return;

      Navigator.of(context).pop();

      await imageLabeler.close();
      imageLabeler = null;

      await _showImageSearchResults(
        image: image,
        detectedLabels:
            detectedLabels,
        products:
            matchedProducts,
      );
    } catch (e) {
      if (imageLabeler != null) {
        await imageLabeler.close();
      }

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Image search failed: $e',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    }
  }

  // =========================================================
  // IMAGE SEARCH RESULTS
  // =========================================================

  Future<void> _showImageSearchResults({
    required XFile image,
    required List<String> detectedLabels,
    required List<QueryDocumentSnapshot>
        products,
  }) async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            height:
                MediaQuery.of(context)
                        .size
                        .height *
                    0.82,
            decoration:
                const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                Container(
                  width: 42,
                  height: 4,
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.grey.shade300,
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 16,
                ),
                const Padding(
                  padding:
                      EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  child: Align(
                    alignment:
                        Alignment.centerLeft,
                    child: Text(
                      'Image Search Results',
                      style:
                          TextStyle(
                        fontSize: 21,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                Padding(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius
                                .circular(
                          12,
                        ),
                        child:
                            Image.file(
                          File(image.path),
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            const Text(
                              'Detected:',
                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                            const SizedBox(
                              height: 4,
                            ),
                            Text(
                              detectedLabels
                                      .isEmpty
                                  ? 'No clear object detected'
                                  : detectedLabels
                                      .take(5)
                                      .join(
                                        ', ',
                                      ),
                              maxLines: 2,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  TextStyle(
                                color: Colors
                                    .grey
                                    .shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 16,
                ),
                const Divider(
                  height: 1,
                ),
                Expanded(
                  child: products
                          .isEmpty
                      ? Center(
                          child:
                              Padding(
                            padding:
                                const EdgeInsets
                                    .all(
                              30,
                            ),
                            child:
                                Column(
                              mainAxisSize:
                                  MainAxisSize
                                      .min,
                              children: [
                                Icon(
                                  Icons
                                      .search_off_rounded,
                                  size: 60,
                                  color: Colors
                                      .grey
                                      .shade400,
                                ),
                                const SizedBox(
                                  height: 14,
                                ),
                                const Text(
                                  'No matching products found',
                                  textAlign:
                                      TextAlign
                                          .center,
                                  style:
                                      TextStyle(
                                    fontSize:
                                        18,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                                const SizedBox(
                                  height: 8,
                                ),
                                Text(
                                  'Try another photo with the product clearly visible.',
                                  textAlign:
                                      TextAlign
                                          .center,
                                  style:
                                      TextStyle(
                                    color: Colors
                                        .grey
                                        .shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding:
                              const EdgeInsets
                                  .all(
                            12,
                          ),
                          itemCount:
                              products.length,
                          itemBuilder:
                              (context,
                                  index) {
                            final doc =
                                products[
                                    index];

                            final data =
                                doc.data()
                                    as Map<String,
                                        dynamic>;

                            final name =
                                data['name']
                                        ?.toString() ??
                                    'Unnamed Product';

                            final imageUrl =
                                data['imageUrl']
                                    ?.toString();

                            final price =
                                _formatBdtPrice(
                              data,
                            );

                            return Card(
                              elevation: 2,
                              margin:
                                  const EdgeInsets
                                      .only(
                                bottom: 10,
                              ),
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  14,
                                ),
                              ),
                              child:
                                  ListTile(
                                contentPadding:
                                    const EdgeInsets
                                        .all(
                                  8,
                                ),
                                leading:
                                    ClipRRect(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    10,
                                  ),
                                  child: imageUrl !=
                                              null &&
                                          imageUrl
                                              .isNotEmpty
                                      ? Image.network(
                                          imageUrl,
                                          width:
                                              65,
                                          height:
                                              65,
                                          fit: BoxFit
                                              .cover,
                                          errorBuilder:
                                              (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            return Container(
                                              width:
                                                  65,
                                              height:
                                                  65,
                                              color: Colors
                                                  .grey
                                                  .shade200,
                                              child:
                                                  const Icon(
                                                Icons
                                                    .image,
                                              ),
                                            );
                                          },
                                        )
                                      : Container(
                                          width:
                                              65,
                                          height:
                                              65,
                                          color: Colors
                                              .grey
                                              .shade200,
                                          child:
                                              const Icon(
                                            Icons
                                                .image,
                                          ),
                                        ),
                                ),
                                title:
                                    Text(
                                  name,
                                  maxLines:
                                      2,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                                subtitle:
                                    Padding(
                                  padding:
                                      const EdgeInsets
                                          .only(
                                    top: 5,
                                  ),
                                  child:
                                      Text(
                                    price,
                                    style:
                                        const TextStyle(
                                      color: Colors
                                          .redAccent,
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                      fontSize:
                                          16,
                                    ),
                                  ),
                                ),
                                trailing:
                                    const Icon(
                                  Icons
                                      .arrow_forward_ios,
                                  size: 16,
                                ),
                                onTap: () {
                                  Navigator.pop(
                                    context,
                                  );

                                  _openProductDetails(
                                    productId:
                                        doc.id,
                                    product:
                                        data,
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
