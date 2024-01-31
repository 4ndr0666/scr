import xml.etree.ElementTree as ET

# Prompt the user for input
source_dev = input("Enter the source device (e.g., /dev/sdX): ")
target_dev = input("Enter the target device (e.g., vdb): ")

# Create the XML configuration
disk = ET.Element("disk", type="block", device="disk")
driver = ET.SubElement(disk, "driver", name="qemu", type="raw")
source = ET.SubElement(disk, "source", dev=source_dev)
target = ET.SubElement(disk, "target", dev=target_dev, bus="virtio")
address = ET.SubElement(disk, "address", type="pci", domain="0x0000", bus="0x00", slot="0x04", function="0x0")

# Create an XML string
xml_config = ET.tostring(disk).decode()

# Print the generated XML configuration
print("\nGenerated XML Configuration:")
print(xml_config)
