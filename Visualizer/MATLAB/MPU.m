classdef MPU < handle
	properties
		gx; gy; gz;
		ax; ay; az;

		gyroXcal = 0; gyroYcal = 0; gyroZcal = 0;

		gyroRoll = 0; gyroPitch = 0; gyroYaw = 0;

		roll = 0; pitch = 0; yaw = 0;

		dtTimer;

		tau;
		gyroScaleFactor;
		accScaleFactor;

		port;
	end

	methods
		function obj = MPU(tau, accFSR, gyroFSR, port)
			% Set tau value
			obj.tau = tau;

			% Set the serial port name
			obj.port = port;

			% Get the accelerometer sensitivity value
			switch accFSR
				case 2
					obj.accScaleFactor = 16384.0;
				case 4
					obj.accScaleFactor = 8192.0;
				case 8
					obj.accScaleFactor = 4096.0;
				case 16
					obj.accScaleFactor = 2048.0;
				otherwise
					fprintf('Please select a given value for the accelerometer:\n')
					fprintf('\t2 [g]\n')
					fprintf('\t4 [g]\n')
					fprintf('\t8 [g]\n')
					fprintf('\t16 [g]\n')
			end

			% Get the gyro sensitivity value
			switch gyroFSR
				case 250
					obj.gyroScaleFactor = 131.0;
				case 500
					obj.gyroScaleFactor = 65.5;
				case 1000
					obj.gyroScaleFactor = 32.8;
				case 2000
					obj.gyroScaleFactor = 16.4;
				otherwise
					fprintf('Please select a given value for the gyroscope:\n')
					fprintf('\t250 [deg/s]\n')
					fprintf('\t500 [deg/s]\n')
					fprintf('\t1000 [deg/s]\n')
					fprintf('\t2000 [deg/s]\n')
			end
		end

		function readSerialStart(obj)
			try
				% Open the serial port with specified parameters
				s = serial(obj.port, 'BaudRate', 9600);
				s.InputBufferSize = 20;
				s.Timeout = 4;
				fopen(s);
			catch ME
				% If serial port fails display error and terminate program
				fprintf('Error: %s\n', ME.message);
				fclose(s);
				delete(s);
				clear s;
				fprintf('Terminating program\n');
				quit cancel;
			end
		end

		function getRawData(obj)
			obj.ax = rand();
			obj.ay = rand();
			obj.az = rand();
			obj.gx = rand();
			obj.gy = rand();
			obj.gz = rand();
		end

		function calibrateGyro(obj, N)
			% Take N readings for each coordinate and add to itself
			for ii = 1:N
				obj.getRawData();
				obj.gyroXcal = obj.gyroXcal + obj.gx;
				obj.gyroYcal = obj.gyroYcal + obj.gy;
				obj.gyroZcal = obj.gyroZcal + obj.gz;
			end

			% Find average offset value
			obj.gyroXcal = obj.gyroXcal / N;
			obj.gyroYcal = obj.gyroYcal / N;
			obj.gyroZcal = obj.gyroZcal / N;

			% Display results to user
			fprintf('Calibration completed:\n')
			fprintf('\tGyro X offset: %0.2f\n', obj.gyroXcal)
			fprintf('\tGyro Y offset: %0.2f\n', obj.gyroYcal)
			fprintf('\tGyro Z offset: %0.2f\n', obj.gyroZcal)

			% Start a timer
			tic;
			obj.dtTimer = toc;
		end

		function processIMUvalues(obj)
			% Get raw data
			obj.getRawData();

			% Subtract the offset calibration values for the gyro
			obj.gx = obj.gx - obj.gyroXcal;
			obj.gy = obj.gy - obj.gyroYcal;
			obj.gz = obj.gz - obj.gyroZcal;

			% Convert gyro values to degrees per secound
			obj.gx = obj.gx / obj.gyroScaleFactor;
			obj.gy = obj.gy / obj.gyroScaleFactor;
			obj.gz = obj.gz / obj.gyroScaleFactor;

			% Convert accelerometer values to g force
			obj.ax = obj.ax / obj.accScaleFactor;
			obj.ay = obj.ay / obj.accScaleFactor;
			obj.az = obj.az / obj.accScaleFactor;
		end

		function compFilter(obj)
			% Get processed values from the IMU
			obj.processIMUvalues();

			% Calculate dt
			dt = toc - obj.dtTimer;
			obj.dtTimer = toc;

			% Find angles from accelerometer
			accelPitch = rad2deg(atan2(obj.ay, obj.az));
			accelRoll = rad2deg(atan2(obj.ax, obj.az));

			% Gyro integration angle
			obj.gyroRoll = obj.gyroRoll - obj.gy * dt;
			obj.gyroPitch = obj.gyroPitch + obj.gx * dt;
			obj.gyroYaw = obj.gyroYaw + obj.gz * dt;

			% Apply complementary filter
			obj.roll = (obj.tau)*(obj.roll - obj.gy * dt) + (1 - obj.tau)*(accelRoll);
			obj.pitch = (obj.tau)*(obj.pitch + obj.gx * dt) + (1 - obj.tau)*(accelPitch);
			obj.yaw = obj.gyroYaw;
		end
 	end

end
