# Patrol

<p align="center">
   <img src='assets/patrol.png' width="200">
</p>

Patrol monitors system resources and records information to a log file in case of excessive RAM or CPU usage. When the log file reaches a certain size, it archives old log files up to a specified number. This is a useful tool for monitoring system performance and managing log files regularly.

## Features

- Monitors system resources (RAM and CPU usage).
- Records information to a log file.
- Archives old log files when the log file size exceeds a specified limit.
- Allows for customization of the log file size limit and the maximum number of archived log files.

## Installation

1. Clone the repository:

   ```
   git clone https://github.com/mkdemir/patrol.git
   ```

2. Navigate to the project directory:

   ```
   cd patrol
   ```

3. Make the script executable:

   ```
   chmod +x patrol.sh
   ```

## Usage

Run the script using the following command:

```
./patrol.sh
```

Alternatively, you can specify custom RAM and CPU thresholds using:

```
./patrol.sh -ram 20 -cpu 10 
```

The script will start monitoring system resources and logging information to a file named `patrol-output.log`. When the log file size exceeds a certain limit, old log files will be archived.

## Configuration

You can customize the following parameters in the script:

- `RAM_THRESHOLD`: The threshold for RAM usage (in percentage).
- `CPU_THRESHOLD`: The threshold for CPU usage (in percentage).
- `RESET_THRESHOLD`: The threshold for resetting the log file (in percentage). (Old)
- `MAX_COMPRESSED_FILES`: The maximum number of compressed log files to keep.
- `LOG_FILE`: The name of the log file.
- `COMPRESSED_LOG_FILE`: The name of the compressed log file.

## Running as a Service

To run the script as a service on Linux systems using systemd, follow these steps:

1. Navigate to the project directory:

   ```
   cd /path/to/patrol
   ```

2. Create a new service file using a text editor, for example:

   ```
   sudo nano patrol.service
   ```

3. Paste the following content into the service file:

   ```
   [Unit]
   Description=Patrol
   After=network.target

   [Service]
   ExecStart=/path/to/patrol/patrol.sh
   WorkingDirectory=/path/to/patrol
   Restart=always

   [Install]
   WantedBy=multi-user.target
   ```

   Note: Update the `ExecStart` and `WorkingDirectory` paths according to the location of your project.

4. Save and close the file (if you're using nano, press `Ctrl + X`, then `Y`, and finally `Enter`).

5. Copy the service file to the systemd directory:

   ```
   sudo cp patrol.service /etc/systemd/system/
   ```

6. Reload systemd to read the new service file and start the service:

   ```
   sudo systemctl daemon-reload
   sudo systemctl start patrol
   ```

7. Check the status of the service to verify that it started successfully:

   ```
   sudo systemctl status patrol
   ```

   The status output will indicate whether the service is running and if there are any errors.

8. Optionally, enable the service to start automatically at boot:

   ```
   sudo systemctl enable patrol
   ```

The system monitor and log rotator service is now successfully running! It will automatically monitor system resources and manage log files when the system starts up.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
