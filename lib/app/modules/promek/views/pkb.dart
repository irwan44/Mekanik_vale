import 'dart:io'; // cek SocketException

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:search_page/search_page.dart';

// Import file terkait warna, model, endpoint, dan komponen Anda
import '../../../componen/color.dart';
import '../../../componen/loading_shammer_booking.dart';
import '../../../data/data_endpoint/boking.dart';
import '../../../data/data_endpoint/kategory.dart';
import '../../../data/data_endpoint/pkb.dart';
import '../../../data/data_endpoint/profile.dart';
import '../../../data/data_endpoint/uploadperpart.dart';
import '../../../data/endpoint.dart';
import '../../../data/localstorage.dart';
import '../../../routes/app_pages.dart';
import '../../boking/componen/card_booking.dart';
import '../componen/card_pkb.dart';
import '../componen/card_uploadperpart.dart';
import '../controllers/promek_controller.dart';

/// Satu halaman utama yang memuat PKB (dengan 2 sub-tab) & PKB TUTUP
class PKBlist extends StatefulWidget {
  const PKBlist({Key? key}) : super(key: key);

  @override
  State<PKBlist> createState() => _PKBlistState();
}

class _PKBlistState extends State<PKBlist>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  // Tanggal terpilih untuk filter (default: hari ini)
  DateTime selectedDate = DateTime.now();
  final controller = Get.put(PromekController());
  // Role user (contoh: 'Mekanik', 'Service Advisor', dsb)
  String userRole = '';
  String selectedStatus = 'Semua';
  // ------------------ TAB CONTROLLERS ------------------
  // Tab controller utama (2 tab: PKB, PKB TUTUP)
  late TabController _mainTabController;

  // Tab controller untuk sub-tab PKB (2 sub tab: List PKB, Lihat Upload Sparepart)
  late TabController _pkbSubTabController;
  // Tab controller untuk sub-tab Booking (11 sub tab: List Booking, Lihat Upload Sparepart)
  late TabController _bookingSubTabController;

  // ------------------ REFRESH CONTROLLERS ------------------
  // Buat RefreshController terpisah untuk masing-masing tab
  late RefreshController _refreshControllerListPKB;
  late RefreshController _refreshControllerListBooking;
  late RefreshController _refreshControllerUpload;
  late RefreshController _refreshControllerPKBTutup;

  @override
  void initState() {
    super.initState();
    // Inisialisasi TabController
    _mainTabController = TabController(length: 3, vsync: this);
    _pkbSubTabController = TabController(length: 2, vsync: this);
    _bookingSubTabController = TabController(length: 11, vsync: this);

    // Inisialisasi RefreshController terpisah untuk masing-masing Tab
    _refreshControllerListPKB = RefreshController();
    _refreshControllerListBooking = RefreshController();
    _refreshControllerUpload = RefreshController();
    _refreshControllerPKBTutup = RefreshController();
  }

  // Supaya state tab tetap terjaga
  @override
  bool get wantKeepAlive => true;

  /// Fungsi untuk memilih tanggal
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Pilih Tanggal PKB',
    );
    if (pickedDate != null && pickedDate != selectedDate) {
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  /// Parse string tglPkb menjadi DateTime
  DateTime? parseTglPkb(String? tglPkb) {
    if (tglPkb == null) return null;
    try {
      // format "yyyy-MM-dd" atau "yyyy-MM-dd HH:mm:ss"
      return DateTime.parse(tglPkb);
    } catch (_) {
      return null;
    }
  }

  /// Fungsi tapping item PKB
  Future<void> handleBookingTapPKB(DataPKB e) async {
    // Ambil data posisi dari local storage
    var posisi = LocalStorages.getPosisi;

    // Jika posisi tersedia dan nilainya adalah "4", maka role adalah Mekanik
    if (posisi != null && posisi.toString() == "4") {
      print("Data posisi berhasil disimpan di local: $posisi (Mekanik)");
      // Role Mekanik -> DetailPKBView
      Get.toNamed(Routes.DetailPKBView, arguments: _buildArguments(e));
    } else {
      // Untuk role selain Mekanik
      if ((e.status ?? '').toLowerCase() == 'pkb') {
        // Buka halaman DETAILPKB
        Get.toNamed(Routes.DETAILPKB, arguments: _buildArguments(e));
      } else {
        // Buka halaman DetailPKBView
        Get.toNamed(Routes.DetailPKBView, arguments: _buildArguments(e));
      }
    }
  }

  Future<void> handleBookingTap(DataBooking e) async {
    HapticFeedback.lightImpact();

    if (kDebugMode) {
      print('Nilai e.namaService: ${e.namaService ?? ''}');
    }

    if (e.bookingStatus != null && e.namaService != null) {
      String kategoriKendaraanId = '';
      final generalData = await API.kategoriID();
      if (generalData != null) {
        final matchingKategori = generalData.dataKategoriKendaraan?.firstWhere(
          (kategori) => kategori.kategoriKendaraan == e.kategoriKendaraan,
          orElse: () => DataKategoriKendaraan(
              kategoriKendaraanId: '', kategoriKendaraan: ''),
        );

        if (matchingKategori != null &&
            matchingKategori is DataKategoriKendaraan) {
          kategoriKendaraanId = matchingKategori.kategoriKendaraanId ?? '';
        }
      }

      final arguments = {
        'tgl_booking': e.tglBooking ?? '',
        'jam_booking': e.jamBooking ?? '',
        'nama': e.nama ?? '',
        'kode_kendaraan': e.kodeKendaraan ?? '',
        'kode_pelanggan': e.kodePelanggan ?? '',
        'kode_booking': e.kodeBooking ?? '',
        'nama_jenissvc': e.namaService ?? '',
        'no_polisi': e.noPolisi ?? '',
        'tahun': e.tahun ?? '',
        'keluhan': e.keluhan ?? '',
        'pm_opt': e.pmopt ?? '',
        'type_order': e.typeOrder ?? '',
        'kategori_kendaraan': e.kategoriKendaraan ?? '',
        'kategori_kendaraan_id': kategoriKendaraanId,
        'warna': e.warna ?? '',
        'hp': e.hp ?? '',
        'vin_number': e.vinNumber ?? '',
        'nama_merk': e.namaMerk ?? '',
        'transmisi': e.transmisi ?? '',
        'nama_tipe': e.namaTipe ?? '',
        'alamat': e.alamat ?? '',
        'booking_id': e.bookingId ?? '',
        'status': e.bookingStatus ?? '',
      };

      if (e.bookingStatus!.toLowerCase() == 'booking') {
        Get.toNamed(Routes.APPROVE, arguments: arguments);
      } else if (e.bookingStatus!.toLowerCase() == 'approve') {
        if (e.typeOrder != null &&
            e.typeOrder!.toLowerCase() == 'emergency service') {
          arguments['location'] = e.location ?? '';
          arguments['location_name'] = e.locationname ?? '';
          Get.toNamed(Routes.EmergencyView, arguments: arguments);
        } else {
          if (e.namaService!.toLowerCase() == 'repair & maintenance') {
            Get.toNamed(Routes.REPAIR_MAINTENEN, arguments: arguments);
          } else if (e.namaService!.toLowerCase() == 'periodical maintenance') {
            Get.toNamed(Routes.StarStopProdical, arguments: arguments);
          } else if (e.namaService!.toLowerCase() == 'tire/ ban') {
            Get.toNamed(Routes.REPAIR_MAINTENEN, arguments: arguments);
          } else if (e.namaService!.toLowerCase() == 'general check up/p2h') {
            Get.toNamed(Routes.GENERAL_CHECKUP, arguments: arguments);
          }
        }
      } else if (e.bookingStatus!.toLowerCase() == 'diproses') {
        if (e.namaService!.toLowerCase() == 'general check up/p2h') {
          Get.toNamed(Routes.GENERAL_CHECKUP, arguments: arguments);
        } else if (e.namaService!.toLowerCase() == 'periodical maintenance') {
          Get.toNamed(
            Routes.StarStopProdical,
            arguments: {
              'tgl_booking': e.tglBooking ?? '',
              'booking_id': e.bookingId.toString(),
              'jam_booking': e.jamBooking ?? '',
              'nama': e.nama ?? '',
              'kode_booking': e.kodeBooking ?? '',
              'kode_kendaraan': e.kodeKendaraan ?? '',
              'kode_pelanggan': e.kodePelanggan ?? '',
              'nama_jenissvc': e.namaService ?? '',
              'no_polisi': e.noPolisi ?? '',
              'tahun': e.tahun ?? '',
              'keluhan': e.keluhan ?? '',
              'kategori_kendaraan': e.kategoriKendaraan ?? '',
              'kategori_kendaraan_id': kategoriKendaraanId,
              'warna': e.warna ?? '',
              'ho': e.hp ?? '',
              'pm_opt': e.pmopt ?? '',
              'vin_number': e.vinNumber ?? '',
              'kode_booking': e.kodeBooking ?? '',
              'nama_merk': e.namaMerk ?? '',
              'transmisi': e.transmisi ?? '',
              'nama_tipe': e.namaTipe ?? '',
              'alamat': e.alamat ?? '',
              'status': e.bookingStatus ?? '',
            },
          );
        } else {
          // handle other namaService cases if needed
        }
      } else {
        Get.toNamed(
          Routes.DetailBooking,
          arguments: arguments,
        );
      }
    } else {
      print('Booking status atau namaService bernilai null');
    }
  }

  /// Membangun argument map untuk DataPKB
  Map<String, dynamic> _buildArguments(DataPKB e) {
    return {
      'id': e.id ?? '',
      'kode_booking': e.kodeBooking ?? '',
      'cabang_id': e.cabangId ?? '',
      'kode_svc': e.kodeSvc ?? '',
      'kode_estimasi': e.kodeEstimasi ?? '',
      'kode_pkb': e.kodePkb ?? '',
      'kode_pelanggan': e.kodePelanggan ?? '',
      'kode_kendaraan': e.kodeKendaraan ?? '',
      'odometer': e.odometer ?? '',
      'pic': e.pic ?? '',
      'hp_pic': e.hpPic ?? '',
      'kode_membership': e.kodeMembership ?? '',
      'kode_paketmember': e.kodePaketmember ?? '',
      'tipe_svc': e.tipeSvc ?? '',
      'tipe_pelanggan': e.tipePelanggan ?? '',
      'referensi': e.referensi ?? '',
      'referensi_teman': e.referensiTeman ?? '',
      'po_number': e.poNumber ?? '',
      'paket_svc': e.paketSvc ?? '',
      'tgl_keluar': e.tglKeluar ?? '',
      'tgl_kembali': e.tglKembali ?? '',
      'km_keluar': e.kmKeluar ?? '',
      'km_kembali': e.kmKembali ?? '',
      'keluhan': e.keluhan ?? '',
      'perintah_kerja': e.perintahKerja ?? '',
      'pergantian_part': e.pergantianPart ?? '',
      'saran': e.saran ?? '',
      'ppn': e.ppn ?? '',
      'penanggung_jawab': e.penanggungJawab ?? '',
      'tgl_estimasi': e.tglEstimasi ?? '',
      'tgl_pkb': e.tglPkb ?? '',
      'tgl_tutup': e.tglTutup ?? '',
      'jam_estimasi_selesai': e.jamEstimasiSelesai ?? '',
      'jam_selesai': e.jamSelesai ?? '',
      'pkb': e.pkb ?? '',
      'tutup': e.tutup ?? '',
      'faktur': e.faktur ?? '',
      'deleted': e.deleted ?? '',
      'notab': e.notab ?? '',
      'status_approval': e.statusApproval ?? '',
      'created_by': e.createdBy ?? '',
      'created_by_pkb': e.createdByPkb ?? '',
      'created_at': e.createdAt ?? '',
      'updated_by': e.updatedBy ?? '',
      'updated_at': e.updatedAt ?? '',
      'kode': e.kode ?? '',
      'no_polisi': e.noPolisi ?? '',
      'id_merk': e.idMerk ?? '',
      'id_tipe': e.idTipe ?? '',
      'tahun': e.tahun ?? '',
      'warna': e.warna ?? '',
      'transmisi': e.transmisi ?? '',
      'no_rangka': e.noRangka ?? '',
      'no_mesin': e.noMesin ?? '',
      'model_karoseri': e.modelKaroseri ?? '',
      'driving_mode': e.drivingMode ?? '',
      'power': e.power ?? '',
      'kategori_kendaraan': e.kategoriKendaraan ?? '',
      'jenis_kontrak': e.jenisKontrak ?? '',
      'jenis_unit': e.jenisUnit ?? '',
      'id_pic_perusahaan': e.idPicPerusahaan ?? '',
      'pic_id_pelanggan': e.picIdPelanggan ?? '',
      'id_customer': e.idCustomer ?? '',
      'nama': e.nama ?? '',
      'alamat': e.alamat ?? '',
      'telp': e.telp ?? '',
      'hp': e.hp ?? '',
      'email': e.email ?? '',
      'kontak': e.kontak ?? '',
      'due': e.due ?? '',
      'jenis_kontrak_x': e.jenisKontrakX ?? '',
      'nama_tagihan': e.namaTagihan ?? '',
      'alamat_tagihan': e.alamatTagihan ?? '',
      'telp_tagihan': e.telpTagihan ?? '',
      'npwp_tagihan': e.npwpTagihan ?? '',
      'pic_tagihan': e.picTagihan ?? '',
      'password': e.password ?? '',
      'remember_token': e.rememberToken ?? '',
      'email_verified_at': e.emailVerifiedAt ?? '',
      'otp': e.otp ?? '',
      'otp_expiry': e.otpExpiry ?? '',
      'gambar': e.gambar ?? '',
      'nama_cabang': e.namaCabang ?? '',
      'nama_merk': e.namaMerk ?? '',
      'vin_number': e.vinNumber ?? '',
      'nama_tipe': e.namaTipe ?? '',
      'status': e.status ?? '',
      'parts': e.parts ?? [],
    };
  }

  /// Fungsi tapping item Upload Sparepart
  Future<void> handleBookingTapSparepart(DataPhotosparepart e) async {
    Get.toNamed(
      Routes.CardDetailPKBSperepart,
      arguments: {
        'id': e.id ?? '',
        'kode_booking': e.kodeBooking ?? '',
        'cabang_id': e.cabangId ?? '',
        'kode_svc': e.kodeSvc ?? '',
        'kode_estimasi': e.kodeEstimasi ?? '',
        'kode_pkb': e.kodePkb ?? '',
        'kode_pelanggan': e.kodePelanggan ?? '',
        'kode_kendaraan': e.kodeKendaraan ?? '',
        'odometer': e.odometer ?? '',
        'pic': e.pic ?? '',
        'hp_pic': e.hpPic ?? '',
        'kode_membership': e.kodeMembership ?? '',
        'kode_paketmember': e.kodePaketmember ?? '',
        'tipe_svc': e.tipeSvc ?? '',
        'tipe_pelanggan': e.tipePelanggan ?? '',
        'referensi': e.referensi ?? '',
        'referensi_teman': e.referensiTeman ?? '',
        'po_number': e.poNumber ?? '',
        'paket_svc': e.paketSvc ?? '',
        'tgl_keluar': e.tglKeluar ?? '',
        'tgl_kembali': e.tglKembali ?? '',
        'km_keluar': e.kmKeluar ?? '',
        'km_kembali': e.kmKembali ?? '',
        'keluhan': e.keluhan ?? '',
        'perintah_kerja': e.perintahKerja ?? '',
        'pergantian_part': e.pergantianPart ?? '',
        'saran': e.saran ?? '',
        'ppn': e.ppn ?? '',
        'penanggung_jawab': e.penanggungJawab ?? '',
        'tgl_estimasi': e.tglEstimasi ?? '',
        'tgl_pkb': e.tglPkb ?? '',
        'tgl_tutup': e.tglTutup ?? '',
        'jam_estimasi_selesai': e.jamEstimasiSelesai ?? '',
        'jam_selesai': e.jamSelesai ?? '',
        'pkb': e.pkb ?? '',
        'tutup': e.tutup ?? '',
        'faktur': e.faktur ?? '',
        'deleted': e.deleted ?? '',
        'notab': e.notab ?? '',
        'status_approval': e.statusApproval ?? '',
        'created_by': e.createdBy ?? '',
        'created_by_pkb': e.createdByPkb ?? '',
        'created_at': e.createdAt ?? '',
        'updated_by': e.updatedBy ?? '',
        'updated_at': e.updatedAt ?? '',
        'kode': e.kode ?? '',
        'no_polisi': e.noPolisi ?? '',
        'id_merk': e.idMerk ?? '',
        'id_tipe': e.idTipe ?? '',
        'tahun': e.tahun ?? '',
        'warna': e.warna ?? '',
        'transmisi': e.transmisi ?? '',
        'no_rangka': e.noRangka ?? '',
        'no_mesin': e.noMesin ?? '',
        'model_karoseri': e.modelKaroseri ?? '',
        'driving_mode': e.drivingMode ?? '',
        'power': e.power ?? '',
        'kategori_kendaraan': e.kategoriKendaraan ?? '',
        'jenis_kontrak': e.jenisKontrak ?? '',
        'jenis_unit': e.jenisUnit ?? '',
        'id_pic_perusahaan': e.idPicPerusahaan ?? '',
        'pic_id_pelanggan': e.picIdPelanggan ?? '',
        'id_customer': e.idCustomer ?? '',
        'nama': e.nama ?? '',
        'alamat': e.alamat ?? '',
        'telp': e.telp ?? '',
        'hp': e.hp ?? '',
        'email': e.email ?? '',
        'kontak': e.kontak ?? '',
        'due': e.due ?? '',
        'jenis_kontrak_x': e.jenisKontrakX ?? '',
        'nama_tagihan': e.namaTagihan ?? '',
        'alamat_tagihan': e.alamatTagihan ?? '',
        'telp_tagihan': e.telpTagihan ?? '',
        'npwp_tagihan': e.npwpTagihan ?? '',
        'pic_tagihan': e.picTagihan ?? '',
        'password': e.password ?? '',
        'remember_token': e.rememberToken ?? '',
        'email_verified_at': e.emailVerifiedAt ?? '',
        'otp': e.otp ?? '',
        'otp_expiry': e.otpExpiry ?? '',
        'gambar': e.gambar ?? '',
        'nama_cabang': e.namaCabang ?? '',
      },
    );
  }

  // ------------------ REFRESHING METHODS ------------------
  /// onRefresh & onLoading untuk List PKB
  void _onRefreshListPKB() {
    HapticFeedback.lightImpact();
    setState(() {
      // Panggil ulang API, dsb.
    });
    _refreshControllerListPKB.refreshCompleted();
  }

  void _onRefreshListBooking() {
    HapticFeedback.lightImpact();
    setState(() {
      // Panggil ulang API, dsb.
    });
    _refreshControllerListPKB.refreshCompleted();
  }

  void _onLoadingListPKB() {
    _refreshControllerListPKB.loadComplete();
  }

  void _onLoadingListBooking() {
    _refreshControllerListBooking.loadComplete();
  }

  /// onRefresh & onLoading untuk Upload Sparepart
  void _onRefreshUpload() {
    HapticFeedback.lightImpact();
    setState(() {});
    _refreshControllerUpload.refreshCompleted();
  }

  void _onLoadingUpload() {
    _refreshControllerUpload.loadComplete();
  }

  /// onRefresh & onLoading untuk PKB TUTUP
  void _onRefreshPKBTutup() {
    HapticFeedback.lightImpact();
    setState(() {});
    _refreshControllerPKBTutup.refreshCompleted();
  }

  void _onLoadingPKBTutup() {
    _refreshControllerPKBTutup.loadComplete();
  }

  @override
  Widget build(BuildContext context) {
    // Mengambil ukuran layar untuk menentukan apakah perangkat tablet
    bool isTablet = MediaQuery.of(context).size.width > 600;
    // Menyesuaikan ukuran font dan ikon berdasarkan perangkat
    double fontSize = isTablet ? 16.0 : 12.0;
    double iconSize = isTablet ? 28.0 : 24.0;
    controller.checkForUpdate();
    super.build(context); // Penting untuk AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 80,
        title: Text(
          'Home',
          style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          // Tombol Kalender untuk filter tanggal
          Row(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: SizedBox(
                height: 15,
                child: Text(
                  'Pilih Berdasarkan Tanggal',
                  style: GoogleFonts.nunito(fontSize: fontSize),
                ),
              ),
            ),
            IconButton(
              onPressed: () => _selectDate(context),
              icon: Icon(
                Icons.calendar_month,
                size: iconSize,
              ),
              tooltip: 'Filter Tanggal PKB',
            ),
          ]),
        ],
        bottom: PreferredSize(
          preferredSize:
              const Size.fromHeight(48.0), // sesuaikan tinggi yang diinginkan
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade200,
            ),
            child: TabBar(
              controller: _mainTabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: MyColors.appPrimaryColor,
              ),
              labelColor: Colors.white,
              dividerColor: Colors.transparent,
              unselectedLabelColor: MyColors.appPrimaryColor,
              tabs: const [
                Padding(
                  padding: EdgeInsets.only(right: 10, left: 10),
                  child: Tab(
                    text: 'Booking',
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(right: 10, left: 10),
                  child: Tab(
                    text: 'PKB',
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(right: 10, left: 10),
                  child: Tab(
                    text: 'PKB TUTUP',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: FutureBuilder<Profile>(
        future: API.profileiD(),
        builder: (context, snapshotProfile) {
          if (snapshotProfile.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshotProfile.hasError) {
            if (snapshotProfile.error is SocketException) {
              return const Center(
                child: Text(
                  'Tidak ada koneksi internet.\n'
                  'Pastikan Anda terhubung ke internet dan coba lagi.',
                  textAlign: TextAlign.center,
                ),
              );
            } else {
              return const Center(
                child: Text(
                  'Terjadi kesalahan saat memuat data.\n'
                  'Silakan coba lagi nanti.',
                  textAlign: TextAlign.center,
                ),
              );
            }
          } else {
            // Profile berhasil
            userRole = snapshotProfile.data?.data?.role?.trim() ?? '';
            return TabBarView(
              controller: _mainTabController,
              children: [
                // TAB 1: Booking (dalamnya ada sub-tab)
                _buildTabContent(),
                // TAB 2: PKB (dalamnya ada sub-tab)
                _buildTabPKBContent(),
                // TAB 3: PKB TUTUP
                _buildTabPkbTutup(),
              ],
            );
          }
        },
      ),
    );
  }

  /// Widget untuk isi tab Booking -> di dalamnya ada sub-tab: (1) List Booking, (2) Lihat Upload Sparepart
  Widget _buildTabBookingContent() {
    return Column(
      children: [
        // Sub TabBar
        TabBar(
          controller: _bookingSubTabController,
          labelColor: MyColors.appPrimaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: MyColors.appPrimaryColor,
          tabs: [
            Tab(text: 'Semua'),
            Tab(text: 'Booking'),
            Tab(text: 'Approve'),
            Tab(text: 'Diproses'),
            Tab(text: 'PKB'),
            Tab(text: 'Selesai Dikerjakan'),
            Tab(text: 'Cancel Booking'),
          ],
        ),
        // Expanded isi dari sub-tab
        Expanded(
          child: TabBarView(
            controller: _bookingSubTabController,
            children: [
              _buildTabContent(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent() {
    return FutureBuilder<Boking>(
      future: API.bokingid(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SingleChildScrollView(child: Loadingshammer());
        } else if (snapshot.hasError) {
          if (snapshot.error is SocketException) {
            return const Center(
              child: Text(
                'Tidak ada koneksi internet.\n'
                'Data Booking gagal dimuat. Periksa koneksi Anda.',
                textAlign: TextAlign.center,
              ),
            );
          } else {
            return const Center(
              child: Text(
                'Terjadi kesalahan. Data Booking gagal dimuat.\n'
                'Silakan coba beberapa saat lagi.',
                textAlign: TextAlign.center,
              ),
            );
          }
        } else {
          // Jika tidak ada data booking secara keseluruhan
          if (!snapshot.hasData ||
              snapshot.data?.dataBooking == null ||
              snapshot.data!.dataBooking!.isEmpty) {
            return Column(
              children: [
                // Baris filter tetap muncul agar user dapat memilih status
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Semua: 0',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: MyColors.appPrimaryColor,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.filter_list,
                            color: MyColors.appPrimaryColor),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (BuildContext context) {
                              return Container(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      title: const Text('Semua'),
                                      onTap: () {
                                        setState(() {
                                          selectedStatus = 'Semua';
                                        });
                                        Navigator.pop(context);
                                      },
                                    ),
                                    ListTile(
                                      title: const Text('Approve'),
                                      onTap: () {
                                        setState(() {
                                          selectedStatus = 'Approve';
                                        });
                                        Navigator.pop(context);
                                      },
                                    ),
                                    ListTile(
                                      title: const Text('Diproses'),
                                      onTap: () {
                                        setState(() {
                                          selectedStatus = 'Diproses';
                                        });
                                        Navigator.pop(context);
                                      },
                                    ),
                                    ListTile(
                                      title: const Text('Ditolak By Sistem'),
                                      onTap: () {
                                        setState(() {
                                          selectedStatus = 'Ditolak By Sistem';
                                        });
                                        Navigator.pop(context);
                                      },
                                    ),
                                    ListTile(
                                      title: const Text('Cancel Booking'),
                                      onTap: () {
                                        setState(() {
                                          selectedStatus = 'Cancel Booking';
                                        });
                                        Navigator.pop(context);
                                      },
                                    ),
                                    ListTile(
                                      title: const Text('Ditolak'),
                                      onTap: () {
                                        setState(() {
                                          selectedStatus = 'Ditolak';
                                        });
                                        Navigator.pop(context);
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        'Tidak ada data Booking pada ${DateFormat('dd-MM-yyyy').format(selectedDate)} dengan status "$selectedStatus".',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: MyColors.appPrimaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            final allBooking = snapshot.data!.dataBooking!;

            // Urutkan data berdasarkan tglBooking (descending)
            allBooking.sort((a, b) {
              DateTime aDate =
                  DateTime.tryParse(a.tglBooking ?? '') ?? DateTime(0);
              DateTime bDate =
                  DateTime.tryParse(b.tglBooking ?? '') ?? DateTime(0);
              return bDate.compareTo(aDate);
            });

            // Filter data berdasarkan tanggal yang dipilih
            final filteredByDate = allBooking.where((booking) {
              final dt = DateTime.tryParse(booking.tglBooking ?? '');
              if (dt == null) return false;
              return dt.year == selectedDate.year &&
                  dt.month == selectedDate.month &&
                  dt.day == selectedDate.day;
            }).toList();

            // Filter tambahan berdasarkan status booking jika status yang dipilih bukan "Semua"
            final filteredData = selectedStatus == 'Semua'
                ? filteredByDate
                : filteredByDate.where((booking) {
                    final status = booking.bookingStatus ?? '';
                    return status.toLowerCase() == selectedStatus.toLowerCase();
                  }).toList();

            return SmartRefresher(
              controller: _refreshControllerListBooking,
              enablePullDown: true,
              header: const WaterDropHeader(),
              onRefresh: _onRefreshListBooking,
              onLoading: _onLoadingListBooking,
              child: Column(
                children: [
                  // Search Box
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15.0, vertical: 10),
                    child: InkWell(
                      onTap: () => showSearch(
                        context: context,
                        delegate: SearchPage<DataBooking>(
                          items: filteredData,
                          searchLabel: 'Cari Booking',
                          searchStyle: GoogleFonts.nunito(color: Colors.black),
                          showItemsOnEmpty: true,
                          failure: Center(
                            child: Text(
                              'Booking tidak ditemukan :(',
                              style: GoogleFonts.nunito(),
                            ),
                          ),
                          filter: (booking) => [
                            booking.nama,
                            booking.noPolisi,
                            booking.bookingStatus,
                            booking.kodeBooking,
                            booking.vinNumber,
                            booking.kodePelanggan,
                          ],
                          builder: (item) => BokingList(
                            items: item,
                            onTap: () => handleBookingTap(item),
                          ),
                        ),
                      ),
                      child: _buildSearchBox('Pencarian Booking'),
                    ),
                  ),
                  // Bari informasi total booking dan tombol filter
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15.0, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total ${selectedStatus == 'Semua' ? 'Semua' : selectedStatus}: ${filteredData.length}',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: MyColors.appPrimaryColor,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.filter_list,
                              color: MyColors.appPrimaryColor),
                          onPressed: () {
                            showModalBottomSheet(
                              showDragHandle: true,
                              enableDrag: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20)),
                              ),
                              context: context,
                              builder: (BuildContext context) {
                                return Container(
                                  padding: const EdgeInsets.all(16.0),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Drag handle
                                        const SizedBox(height: 12),
                                        // Header
                                        Text(
                                          'Filter Booking',
                                          style: GoogleFonts.nunito(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Pilih status filter booking:',
                                          style: GoogleFonts.nunito(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        const Divider(),
                                        // List pilihan filter
                                        ListTile(
                                          leading: Icon(Icons.list,
                                              color: MyColors.appPrimaryColor),
                                          title: const Text('Semua'),
                                          onTap: () {
                                            setState(() {
                                              selectedStatus = 'Semua';
                                            });
                                            Navigator.pop(context);
                                          },
                                        ),
                                        ListTile(
                                          leading: Icon(
                                              Icons.home_repair_service,
                                              color: MyColors.appPrimaryColor),
                                          title: const Text('Booking'),
                                          onTap: () {
                                            setState(() {
                                              selectedStatus = 'Booking';
                                            });
                                            Navigator.pop(context);
                                          },
                                        ),
                                        ListTile(
                                          leading: Icon(Icons.check_circle,
                                              color: MyColors.appPrimaryColor),
                                          title: const Text('Approved'),
                                          onTap: () {
                                            setState(() {
                                              selectedStatus = 'Approve';
                                            });
                                            Navigator.pop(context);
                                          },
                                        ),
                                        ListTile(
                                          leading: Icon(Icons.autorenew,
                                              color: MyColors.appPrimaryColor),
                                          title: const Text('Diproses'),
                                          onTap: () {
                                            setState(() {
                                              selectedStatus = 'Diproses';
                                            });
                                            Navigator.pop(context);
                                          },
                                        ),
                                        ListTile(
                                          leading: Icon(Icons.cancel,
                                              color: MyColors.appPrimaryColor),
                                          title:
                                              const Text('Ditolak By Sistem'),
                                          onTap: () {
                                            setState(() {
                                              selectedStatus =
                                                  'Ditolak By Sistem';
                                            });
                                            Navigator.pop(context);
                                          },
                                        ),
                                        ListTile(
                                          leading: Icon(
                                              Icons.remove_circle_outline,
                                              color: MyColors.appPrimaryColor),
                                          title: const Text('Cancel Booking'),
                                          onTap: () {
                                            setState(() {
                                              selectedStatus = 'Cancel Booking';
                                            });
                                            Navigator.pop(context);
                                          },
                                        ),
                                        ListTile(
                                          leading: Icon(Icons.block,
                                              color: MyColors.appPrimaryColor),
                                          title: const Text('Ditolak'),
                                          onTap: () {
                                            setState(() {
                                              selectedStatus = 'Ditolak';
                                            });
                                            Navigator.pop(context);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  // Tampilkan pesan jika tidak ada data setelah filter
                  filteredData.isEmpty
                      ? Expanded(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Text(
                                'Tidak ada data Booking pada ${DateFormat('dd-MM-yyyy').format(selectedDate)} dengan status "$selectedStatus".',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: MyColors.appPrimaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Expanded(
                          child: AnimationLimiter(
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              itemCount: filteredData.length,
                              itemBuilder: (context, index) {
                                final e = filteredData[index];
                                return AnimationConfiguration.staggeredList(
                                  position: index,
                                  duration: const Duration(milliseconds: 475),
                                  child: SlideAnimation(
                                    verticalOffset: 50.0,
                                    child: FadeInAnimation(
                                      child: BokingList(
                                        items: e,
                                        onTap: () => handleBookingTap(e),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                ],
              ),
            );
          }
        }
      },
    );
  }

  /// Widget untuk isi tab PKB -> di dalamnya ada sub-tab: (1) List PKB, (2) Lihat Upload Sparepart
  Widget _buildTabPKBContent() {
    return Column(
      children: [
        // Sub TabBar
        TabBar(
          controller: _pkbSubTabController,
          labelColor: MyColors.appPrimaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: MyColors.appPrimaryColor,
          tabs: [
            Tab(text: 'List PKB'),
            Tab(text: 'Upload Sparepart'),
          ],
        ),
        // Expanded isi dari sub-tab
        Expanded(
          child: TabBarView(
            controller: _pkbSubTabController,
            children: [
              // Sub-tab index 0: List PKB
              _buildListPKBTab(),
              // Sub-tab index 1: Lihat Upload Sparepart
              _buildUploadSparepartTab(),
            ],
          ),
        ),
      ],
    );
  }

  /// Sub-tab: List PKB (khusus status=PKB, filter by tgl, + searching)
  Widget _buildListPKBTab() {
    return FutureBuilder<PKB>(
      future: API.PKBID(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SingleChildScrollView(child: Loadingshammer());
        } else if (snapshot.hasError) {
          if (snapshot.error is SocketException) {
            return const Center(
              child: Text(
                'Tidak ada koneksi internet.\n'
                'Data PKB gagal dimuat. Periksa koneksi Anda.',
                textAlign: TextAlign.center,
              ),
            );
          } else {
            return const Center(
              child: Text(
                'Terjadi kesalahan. Data PKB gagal dimuat.\n'
                'Silakan coba beberapa saat lagi.',
                textAlign: TextAlign.center,
              ),
            );
          }
        } else {
          if (!snapshot.hasData ||
              snapshot.data?.dataPKB == null ||
              snapshot.data!.dataPKB!.isEmpty) {
            return _buildEmptyPKB();
          } else {
            final allPkb = snapshot.data!.dataPKB!;
            // Sort (descending) berdasarkan angka di akhir kodePkb
            allPkb.sort((a, b) {
              int extractNumber(String kodePkb) {
                RegExp regex = RegExp(r'(\d+)$');
                Match? match = regex.firstMatch(kodePkb);
                return match != null ? int.parse(match.group(0)!) : 0;
              }

              int aNumber = extractNumber(a.kodePkb ?? '');
              int bNumber = extractNumber(b.kodePkb ?? '');
              return bNumber.compareTo(aNumber);
            });

            // Filter by status=PKB dan tgl
            final filteredData = allPkb.where((pkb) {
              final dt = parseTglPkb(pkb.tglPkb);
              final status = pkb.status?.toUpperCase() ?? '';
              if (dt == null) return false;
              final sameDate = dt.year == selectedDate.year &&
                  dt.month == selectedDate.month &&
                  dt.day == selectedDate.day;
              return sameDate && (status == 'PKB');
            }).toList();

            if (filteredData.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    'Tidak ada data PKB pada '
                    '${DateFormat('dd-MM-yyyy').format(selectedDate)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: MyColors.appPrimaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }
            // Search Box (khusus sub-tab ini)
            final searchBox = InkWell(
              onTap: () => showSearch(
                context: context,
                delegate: SearchPage<DataPKB>(
                  items: filteredData,
                  searchLabel: 'Cari PKB Service',
                  searchStyle: GoogleFonts.nunito(color: Colors.black),
                  showItemsOnEmpty: true,
                  failure: Center(
                    child: Text(
                      'PKB Service tidak ditemukan :(',
                      style: GoogleFonts.nunito(),
                    ),
                  ),
                  filter: (pkb) => [
                    pkb.nama,
                    pkb.noPolisi,
                    pkb.status,
                    pkb.createdByPkb,
                    pkb.createdBy,
                    pkb.tglEstimasi,
                    pkb.tipeSvc,
                    pkb.kodePkb,
                    pkb.vinNumber,
                    pkb.kodePelanggan,
                  ],
                  builder: (item) => PkbList(
                    items: item,
                    onTap: () => handleBookingTapPKB(item),
                  ),
                ),
              ),
              child: _buildSearchBox('Pencarian PKB Service'),
            );
            // Gunakan refreshController khusus untuk List PKB
            return SmartRefresher(
              controller: _refreshControllerListPKB,
              enablePullDown: true,
              header: const WaterDropHeader(),
              onRefresh: _onRefreshListPKB,
              onLoading: _onLoadingListPKB,
              child: Column(
                children: [
                  // SearchBox
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15.0, vertical: 10),
                    child: searchBox,
                  ),
                  Text(
                    'Total PKB: ${filteredData.length}',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: MyColors.appPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: AnimationLimiter(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: filteredData.length,
                        itemBuilder: (context, index) {
                          final e = filteredData[index];
                          return AnimationConfiguration.staggeredList(
                            position: index,
                            duration: const Duration(milliseconds: 475),
                            child: SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(
                                child: PkbList(
                                  items: e,
                                  onTap: () => handleBookingTapPKB(e),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        }
      },
    );
  }

  /// Sub-tab: Lihat Upload Sparepart
  Widget _buildUploadSparepartTab() {
    return FutureBuilder<UploadSpertpart>(
      future: API.ListSperpartID(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SingleChildScrollView(child: Loadingshammer());
        } else if (snapshot.hasError) {
          if (snapshot.error is SocketException) {
            return const Center(
              child: Text(
                'Tidak ada koneksi internet.\n'
                'Data Sparepart gagal dimuat. Periksa koneksi Anda.',
                textAlign: TextAlign.center,
              ),
            );
          } else {
            return const Center(
              child: Text(
                'Terjadi kesalahan. Data Sparepart gagal dimuat.\n'
                'Silakan coba beberapa saat lagi.',
                textAlign: TextAlign.center,
              ),
            );
          }
        } else {
          if (!snapshot.hasData ||
              snapshot.data!.dataPhotosparepart == null ||
              snapshot.data!.dataPhotosparepart!.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/icons/booking.png',
                      width: 120.0,
                      height: 120.0,
                      fit: BoxFit.cover,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Belum ada data Foto Sparepart',
                      style: TextStyle(
                        color: MyColors.appPrimaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            final allSparepart = snapshot.data!.dataPhotosparepart!;
            // Sort descending by kodePkb last digits
            allSparepart.sort((a, b) {
              int extractNumber(String kodePkb) {
                RegExp regex = RegExp(r'(\d+)$');
                Match? match = regex.firstMatch(kodePkb);
                return match != null ? int.parse(match.group(0)!) : 0;
              }

              int aNumber = extractNumber(a.kodePkb ?? '');
              int bNumber = extractNumber(b.kodePkb ?? '');
              return bNumber.compareTo(aNumber);
            });

            // Filter by tglPkb == selectedDate
            final filteredSparepart = allSparepart.where((item) {
              final dt = parseTglPkb(item.tglPkb);
              if (dt == null) return false;
              return dt.year == selectedDate.year &&
                  dt.month == selectedDate.month &&
                  dt.day == selectedDate.day;
            }).toList();

            if (filteredSparepart.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    'Tidak ada data Sparepart pada '
                    '${DateFormat('dd-MM-yyyy').format(selectedDate)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: MyColors.appPrimaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }

            // SearchBox (untuk Sparepart)
            final searchBox = InkWell(
              onTap: () => showSearch(
                context: context,
                delegate: SearchPage<DataPhotosparepart>(
                  items: filteredSparepart,
                  searchLabel: 'Cari Sparepart',
                  searchStyle: GoogleFonts.nunito(color: Colors.black),
                  showItemsOnEmpty: true,
                  failure: Center(
                    child: Text(
                      'Data Sparepart tidak ditemukan :(',
                      style: GoogleFonts.nunito(),
                    ),
                  ),
                  filter: (data) => [
                    data.nama,
                    data.noPolisi,
                    data.createdBy,
                    data.createdByPkb,
                    data.kodePkb,
                    data.kodePelanggan,
                  ],
                  builder: (item) => PkbListSperpart(
                    items: item,
                    onTap: () => handleBookingTapSparepart(item),
                  ),
                ),
              ),
              child: _buildSearchBox('Pencarian Sparepart'),
            );

            // Gunakan refreshController khusus untuk Upload Sparepart
            return SmartRefresher(
              controller: _refreshControllerUpload,
              enablePullDown: true,
              header: const WaterDropHeader(),
              onRefresh: _onRefreshUpload,
              onLoading: _onLoadingUpload,
              child: Column(
                children: [
                  // Search box
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15.0, vertical: 10),
                    child: searchBox,
                  ),
                  Text(
                    'Total Sparepart: ${filteredSparepart.length}',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: MyColors.appPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: AnimationLimiter(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: filteredSparepart.length,
                        itemBuilder: (context, index) {
                          final e = filteredSparepart[index];
                          return AnimationConfiguration.staggeredList(
                            position: index,
                            duration: const Duration(milliseconds: 475),
                            child: SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(
                                child: PkbListSperpart(
                                  items: e,
                                  onTap: () => handleBookingTapSparepart(e),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        }
      },
    );
  }

  /// Tab PKB TUTUP (status=PKB TUTUP, filter by tgl)
  Widget _buildTabPkbTutup() {
    return FutureBuilder<PKB>(
      future: API.PKBID(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SingleChildScrollView(child: Loadingshammer());
        } else if (snapshot.hasError) {
          if (snapshot.error is SocketException) {
            return const Center(
              child: Text(
                'Tidak ada koneksi internet.\n'
                'Data PKB gagal dimuat. Periksa koneksi Anda.',
                textAlign: TextAlign.center,
              ),
            );
          } else {
            return const Center(
              child: Text(
                'Terjadi kesalahan. Data PKB gagal dimuat.\n'
                'Silakan coba beberapa saat lagi.',
                textAlign: TextAlign.center,
              ),
            );
          }
        } else {
          if (!snapshot.hasData ||
              snapshot.data?.dataPKB == null ||
              snapshot.data!.dataPKB!.isEmpty) {
            return _buildEmptyPKB();
          } else {
            final allPkb = snapshot.data!.dataPKB!;
            // Sort descending
            allPkb.sort((a, b) {
              int extractNumber(String kodePkb) {
                RegExp regex = RegExp(r'(\d+)$');
                Match? match = regex.firstMatch(kodePkb);
                return match != null ? int.parse(match.group(0)!) : 0;
              }

              int aNumber = extractNumber(a.kodePkb ?? '');
              int bNumber = extractNumber(b.kodePkb ?? '');
              return bNumber.compareTo(aNumber);
            });

            // Filter by status=PKB TUTUP dan tgl
            final filteredData = allPkb.where((pkb) {
              final dt = parseTglPkb(pkb.tglPkb);
              final status = pkb.status?.toUpperCase() ?? '';
              if (dt == null) return false;
              final sameDate = dt.year == selectedDate.year &&
                  dt.month == selectedDate.month &&
                  dt.day == selectedDate.day;
              return sameDate && (status == 'PKB TUTUP');
            }).toList();

            if (filteredData.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    'Tidak ada data PKB TUTUP pada '
                    '${DateFormat('dd-MM-yyyy').format(selectedDate)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: MyColors.appPrimaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }

            // SearchBox (opsional, jika ingin searching di PKB TUTUP)
            final searchBox = InkWell(
              onTap: () => showSearch(
                context: context,
                delegate: SearchPage<DataPKB>(
                  items: filteredData,
                  searchLabel: 'Cari PKB TUTUP',
                  searchStyle: GoogleFonts.nunito(color: Colors.black),
                  showItemsOnEmpty: true,
                  failure: Center(
                    child: Text(
                      'PKB TUTUP tidak ditemukan :(',
                      style: GoogleFonts.nunito(),
                    ),
                  ),
                  filter: (pkb) => [
                    pkb.nama,
                    pkb.noPolisi,
                    pkb.status,
                    pkb.createdByPkb,
                    pkb.createdBy,
                    pkb.tglEstimasi,
                    pkb.tipeSvc,
                    pkb.kodePkb,
                    pkb.vinNumber,
                    pkb.kodePelanggan,
                  ],
                  builder: (item) => PkbList(
                    items: item,
                    onTap: () => handleBookingTapPKB(item),
                  ),
                ),
              ),
              child: _buildSearchBox('Pencarian PKB TUTUP'),
            );

            // Gunakan refreshController khusus untuk PKB TUTUP
            return SmartRefresher(
              controller: _refreshControllerPKBTutup,
              enablePullDown: true,
              header: const WaterDropHeader(),
              onRefresh: _onRefreshPKBTutup,
              onLoading: _onLoadingPKBTutup,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15.0,
                      vertical: 10,
                    ),
                    child: searchBox,
                  ),
                  Text(
                    'Total PKB TUTUP: ${filteredData.length}',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: MyColors.appPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: AnimationLimiter(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: filteredData.length,
                        itemBuilder: (context, index) {
                          final e = filteredData[index];
                          return AnimationConfiguration.staggeredList(
                            position: index,
                            duration: const Duration(milliseconds: 475),
                            child: SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(
                                child: PkbList(
                                  items: e,
                                  onTap: () => handleBookingTapPKB(e),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        }
      },
    );
  }

  /// Widget box search
  Widget _buildSearchBox(String hintText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 4,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: MyColors.appPrimaryColor.withOpacity(0.8),
          ),
          const SizedBox(width: 10),
          Text(
            hintText,
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBooking() {
    return Center(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icons/booking.png',
              width: 120.0,
              height: 120.0,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 10),
            Text(
              'Belum ada data PKB',
              style: TextStyle(
                color: MyColors.appPrimaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget jika data PKB kosong
  Widget _buildEmptyPKB() {
    return Center(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icons/booking.png',
              width: 120.0,
              height: 120.0,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 10),
            Text(
              'Belum ada data PKB',
              style: TextStyle(
                color: MyColors.appPrimaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Contoh fungsi logout (jika diperlukan)
  void logout() {
    LocalStorages.deleteToken();
    Get.offAllNamed(Routes.SIGNIN);
  }
}
