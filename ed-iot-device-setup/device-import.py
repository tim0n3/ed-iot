import csv
import datetime
import logging
import os
import sys
import time

sys.path.append(os.path.join(os.path.dirname(__file__), "..", "manager"))  # noqa
import cloudiot_mqtt_example  # noqa
import manager  # noqa


logging.getLogger("googleapiclient.discovery_cache").setLevel(logging.CRITICAL)

cloud_region = "europe-west1"
device_id_template = "test-device-{}"
gateway_id_template = "ed-default{}"
topic_id = "test-device-events-topic-{}".format(int(time.time()))

ca_cert_path = "resources/roots.pem"
log_path = "config_log.csv"
rsa_cert_path = "resources/ed-rsa_cert.pem"
rsa_private_path = "resources/ed-rsa_private.pem"

if (
    "GOOGLE_CLOUD_PROJECT" not in os.environ
    or "GOOGLE_APPLICATION_CREDENTIALS" not in os.environ
):
    print("You must set GCLOUD_PROJECT and GOOGLE_APPLICATION_CREDENTIALS")
    quit()

project_id = os.environ["GOOGLE_CLOUD_PROJECT"]
service_account_json = os.environ["GOOGLE_APPLICATION_CREDENTIALS"]

pubsub_topic = "projects/{}/topics/{}".format(project_id, topic_id)
registry_id = "test-registry-{}".format(int(time.time()))

base_url = "https://console.cloud.google.com/iot/locations/{}".format(cloud_region)
edit_template = "{}/registries/{}?project={}".format(base_url, "{}", "{}")

device_url_template = "{}/registries/{}/devices/{}?project={}".format(
    base_url, "{}", "{}", "{}"
)

mqtt_bridge_hostname = "mqtt.googleapis.com"
mqtt_bridge_port = 8883

num_messages = 15
jwt_exp_time = 20
listen_time = 30


if __name__ == "__main__":
    print("Running demo")

    gateway_id = device_id_template.format("RS256")
    device_id = device_id_template.format("noauthbind")

    print("Creating registry: {}".format(registry_id))
    manager.create_registry(
        service_account_json, project_id, cloud_region, pubsub_topic, registry_id
    )

    print("Creating gateway: {}".format(gateway_id))
    manager.create_gateway(
        service_account_json,
        project_id,
        cloud_region,
        registry_id,
        None,
        gateway_id,
        rsa_cert_path,
        "RS256",
    )

    print("Creating device to bind: {}".format(device_id))
    manager.create_device(
        service_account_json, project_id, cloud_region, registry_id, device_id
    )

    print("Binding device")
    manager.bind_device_to_gateway(
        service_account_json,
        project_id,
        cloud_region,
        registry_id,
        device_id,
        gateway_id,
    )

    print("Listening for messages for {} seconds".format(listen_time))
    print("Try setting configuration in: ")
    print("\t{}".format(edit_template.format(registry_id, project_id)))
    try:
        input("Press enter to continue")
    except SyntaxError:
        pass

    def log_callback(client):
        def log_on_message(unused_client, unused_userdata, message):
            if not os.path.exists(log_path):
                with open(log_path, "w") as csvfile:
                    logwriter = csv.writer(csvfile, dialect="excel")
                    logwriter.writerow(["time", "topic", "data"])

            with open(log_path, "a") as csvfile:
                logwriter = csv.writer(csvfile, dialect="excel")
                logwriter.writerow(
                    [
                        datetime.datetime.now(tz=datetime.timezone.utc).isoformat(),
                        message.topic,
                        message.payload,
                    ]
                )

        client.on_message = log_on_message

    cloudiot_mqtt_example.listen_for_messages(
        service_account_json,
        project_id,
        cloud_region,
        registry_id,
        device_id,
        gateway_id,
        num_messages,
        rsa_private_path,
        "RS256_X509",
        ca_cert_path,
        mqtt_bridge_hostname,
        mqtt_bridge_port,
        jwt_exp_time,
        listen_time,
        log_callback,
    )

    print("Publishing messages demo")
    print("Publishing: {} messages".format(num_messages))
    cloudiot_mqtt_example.send_data_from_bound_device(
        service_account_json,
        project_id,
        cloud_region,
        registry_id,
        device_id,
        gateway_id,
        num_messages,
        rsa_private_path,
        "RS256_X509",
        ca_cert_path,
        mqtt_bridge_hostname,
        mqtt_bridge_port,
        jwt_exp_time,
        "Hello from gateway_demo.py",
    )

    print("You can read the state messages for your device at this URL:")
    print("\t{}".format(device_url_template).format(registry_id, device_id, project_id))
    try:
        input("Press enter to continue after reading the messages.")
    except SyntaxError:
        pass

    # Clean up
    manager.unbind_device_from_gateway(
        service_account_json,
        project_id,
        cloud_region,
        registry_id,
        device_id,
        gateway_id,
    )
    manager.delete_device(
        service_account_json, project_id, cloud_region, registry_id, device_id
    )
    manager.delete_device(
        service_account_json, project_id, cloud_region, registry_id, gateway_id
    )
    manager.delete_registry(service_account_json, project_id, cloud_region, registry_id)