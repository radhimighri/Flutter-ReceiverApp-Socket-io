import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

void main() => runApp(ReceiverApp());

class ReceiverApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: ReceiverScreen(),
    );
  }
}

class ReceiverScreen extends StatefulWidget {
  const ReceiverScreen({super.key});

  @override
  _ReceiverScreenState createState() => _ReceiverScreenState();
}

class _ReceiverScreenState extends State<ReceiverScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Position? _currentPosition;

  Future<BitmapDescriptor> createActiveNearByDriverIconMarker() async {
    // if (activeNearbyIcon == null) {
    ImageConfiguration imageConfiguration =
        createLocalImageConfiguration(context, size: const Size(1, 1));
    return await BitmapDescriptor.fromAssetImage(
        imageConfiguration, "assets/images/car.png");
    // .then((value) {
    // activeNearbyIcon = value;
    // });
    // }
  }

  void _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('Location permission denied');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = position;
        // _mapController?.animateCamera(CameraUpdate.newLatLng(
        //     LatLng(position.latitude, position.longitude)));
      });
    } catch (e) {
      print(e);
    }
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red,
        title: const Text('Receiver App'),
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        myLocationButtonEnabled: true,
        initialCameraPosition: CameraPosition(
          target: LatLng(_currentPosition?.latitude ?? 0.0,
              _currentPosition?.longitude ?? 0.0), // Initial map position
          zoom: 14,
        ),
        markers: _markers,
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    setState(() {
      _mapController = controller;
    });

    // Connect to the Socket.IO server
    IO.Socket socket = IO.io('http://127.0.0.1:3000', <String, dynamic>{
      'transports': ['websocket'],
      'forceNew': true,
    });

    // Listen for location updates from the sender app
    socket.on('location', (data) {
      double latitude = data['latitude'];
      double longitude = data['longitude'];

      // Update the map with the new location marker
      _updateMarker(LatLng(latitude, longitude));
    });

    // Connect to the server
    socket.connect();

    // socket?.disconnect();
  }

  void _updateMarker(LatLng location) async {
    _markers.clear();
    _markers.add(Marker(
      markerId: const MarkerId('sender_location'),
      position: location,
      icon: await createActiveNearByDriverIconMarker(),
    ));
    setState(() {
      // Move the camera to the updated location
      if (_mapController != null) {
        _mapController?.animateCamera(CameraUpdate.newLatLng(location));
      }
    });
  }
}
