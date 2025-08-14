import unittest
import os
import shutil
import tarfile
import json
import time
from datetime import datetime
from unittest.mock import MagicMock, patch

# Temporarily add the script's directory to the path to import it
# In a real scenario, this would be a proper package.
sys.path.append(os.getcwd())
import takeout_processor as tp

class TestTakeoutProcessor(unittest.TestCase):
    """
    Test suite for the Takeout Processor script.
    This suite creates a temporary file structure to simulate the real environment,
    ensuring that no actual user data is touched.
    """
    def setUp(self):
        """Set up a temporary directory structure for each test."""
        self.base_dir = "/tmp/test_takeout_project"
        self.source_dir = os.path.join(self.base_dir, "00-ALL-ARCHIVES")
        self.extracted_dir = os.path.join(self.base_dir, "02-extracted")
        self.organized_dir = os.path.join(self.base_dir, "03-organized/My-Photos")
        self.trash_dir = os.path.join(self.base_dir, "04-trash")
        self.quarantine_dir = os.path.join(self.trash_dir, "quarantined_artifacts")
        
        # Create all necessary directories
        for d in [self.source_dir, self.extracted_dir, self.organized_dir, self.quarantine_dir]:
            os.makedirs(d, exist_ok=True)
            
        # Mock the CONFIG global in the script
        tp.CONFIG["SOURCE_ARCHIVES_DIR"] = self.source_dir
        tp.CONFIG["EXTRACTED_DIR"] = self.extracted_dir
        tp.CONFIG["ORGANIZED_DIR"] = self.organized_dir
        tp.CONFIG["TRASH_DIR"] = self.trash_dir
        tp.CONFIG["QUARANTINE_DIR"] = self.quarantine_dir
        
        # Mock tqdm to prevent progress bar output during tests
        self.mock_tqdm = tp.dummy_tqdm

    def tearDown(self):
        """Clean up the temporary directory structure after each test."""
        shutil.rmtree(self.base_dir)

    def _create_dummy_tar(self, name, num_files, file_size_mb):
        """Helper to create a dummy .tgz file with specified contents."""
        archive_path = os.path.join(self.source_dir, name)
        file_content = b'a' * (file_size_mb * 1024 * 1024)
        with tarfile.open(archive_path, 'w:gz') as tf:
            for i in range(num_files):
                dummy_file_path = f"/tmp/dummy_file_{i}.txt"
                with open(dummy_file_path, 'wb') as f:
                    f.write(file_content)
                tf.add(dummy_file_path, arcname=f"file_{i}.txt")
                os.remove(dummy_file_path)
        return archive_path

    def test_unpack_0_byte_artifact_quarantines_by_default(self):
        """Verify that a 0-byte file is quarantined when auto_delete is False."""
        artifact_path = os.path.join(self.source_dir, "empty.tgz")
        with open(artifact_path, 'w') as f:
            pass # Create empty file
        
        result = tp.unpack_regular_archive(artifact_path, self.extracted_dir, False, self.mock_tqdm)
        
        self.assertFalse(result) # Should return False
        self.assertFalse(os.path.exists(artifact_path)) # Original should be gone
        self.assertTrue(os.path.exists(os.path.join(self.quarantine_dir, "empty.tgz"))) # Should be in quarantine

    def test_unpack_0_byte_artifact_deletes_with_flag(self):
        """Verify that a 0-byte file is deleted when auto_delete is True."""
        artifact_path = os.path.join(self.source_dir, "empty.tgz")
        with open(artifact_path, 'w') as f:
            pass
            
        result = tp.unpack_regular_archive(artifact_path, self.extracted_dir, True, self.mock_tqdm)
        
        self.assertFalse(result)
        self.assertFalse(os.path.exists(artifact_path)) # Original should be gone
        self.assertFalse(os.path.exists(os.path.join(self.quarantine_dir, "empty.tgz"))) # Should not be in quarantine

    def test_repackaging_creates_correct_number_of_parts(self):
        """Verify the repackaging logic splits a large archive correctly."""
        tp.REPACKAGE_CHUNK_SIZE_GB = 0.01 # 10MB for testing
        
        # Create a ~30MB archive, which should result in 3 parts
        archive_path = self._create_dummy_tar("large_archive.tgz", 3, 10)
        
        result = tp.plan_and_repackage_archive(archive_path, self.source_dir, self.mock_tqdm)
        
        self.assertTrue(result)
        parts = [f for f in os.listdir(self.source_dir) if f.startswith("large_archive.part-")]
        self.assertEqual(len(parts), 3)
        self.assertTrue(os.path.exists(os.path.join(self.source_dir, "large_archive.part-01.tgz")))
        self.assertTrue(os.path.exists(os.path.join(self.source_dir, "large_archive.part-02.tgz")))
        self.assertTrue(os.path.exists(os.path.join(self.source_dir, "large_archive.part-03.tgz")))

    def test_repackaging_resume_logic(self):
        """Verify the repackaging logic correctly resumes after a 'crash'."""
        tp.REPACKAGE_CHUNK_SIZE_GB = 0.01 # 10MB
        archive_path = self._create_dummy_tar("large_archive_for_resume.tgz", 4, 10) # Should create 4 parts
        
        # Simulate a crash after part 1 and 2 are created
        os.rename(archive_path, os.path.join(self.source_dir, "large_archive_for_resume.tgz")) # Put it back in source
        self._create_dummy_tar("large_archive_for_resume.part-01.tgz", 1, 1) # Create fake part 1
        self._create_dummy_tar("large_archive_for_resume.part-02.tgz", 1, 1) # Create fake part 2
        
        # Run the repackaging function again
        result = tp.plan_and_repackage_archive(archive_path, self.source_dir, self.mock_tqdm)
        
        self.assertTrue(result)
        parts = [f for f in os.listdir(self.source_dir) if f.startswith("large_archive_for_resume.part-")]
        # We should now have 4 total parts (the 2 fake ones + 2 new ones)
        self.assertEqual(len(parts), 4)
        self.assertTrue(os.path.exists(os.path.join(self.source_dir, "large_archive_for_resume.part-03.tgz")))
        self.assertTrue(os.path.exists(os.path.join(self.source_dir, "large_archive_for_resume.part-04.tgz")))

    def _create_dummy_photo_files(self, name, timestamp):
        """Helper to create a dummy photo and its metadata JSON."""
        photo_path = os.path.join(self.extracted_dir, "Takeout/Google Photos", f"{name}.jpg")
        json_path = os.path.join(self.extracted_dir, "Takeout/Google Photos", f"{name}.jpg.json")
        os.makedirs(os.path.dirname(photo_path), exist_ok=True)

        with open(photo_path, 'w') as f:
            f.write("dummy photo data")
        
        metadata = {
            "title": f"{name}.jpg",
            "photoTakenTime": {
                "timestamp": str(int(timestamp.timestamp())),
                "formatted": timestamp.strftime('%b %d, %Y, %I:%M:%S %p %Z')
            }
        }
        with open(json_path, 'w') as f:
            json.dump(metadata, f)

    def test_organize_photos_handles_collisions(self):
        """Verify the photo organizer correctly renames files with the same timestamp."""
        # Create two different photos with the exact same timestamp
        ts = datetime(2023, 10, 16, 12, 0, 0)
        self._create_dummy_photo_files("photoA", ts)
        self._create_dummy_photo_files("photoB", ts)
        
        tp.organize_photos(self.extracted_dir, self.organized_dir, self.mock_tqdm)
        
        organized_files = os.listdir(self.organized_dir)
        self.assertEqual(len(organized_files), 2)
        
        expected_name_1 = "2023-10-16_12h00m00s.jpg"
        expected_name_2 = "2023-10-16_12h00m00s_1.jpg"
        
        # Check that both expected filenames exist
        self.assertTrue(expected_name_1 in organized_files)
        self.assertTrue(expected_name_2 in organized_files)

if __name__ == '__main__':
    # Add a dummy main function and arg parser for context, as the script expects it
    def dummy_main(args):
        print("Running tests...")
        # This is a bit of a hack to get the test runner to work inside the script's structure
        # In a real package, you'd run `python -m unittest test_takeout_processor.py`
        suite = unittest.TestSuite()
        suite.addTest(unittest.makeSuite(TestTakeoutProcessor))
        runner = unittest.TextTestRunner()
        runner.run(suite)

    parser = argparse.ArgumentParser()
    parser.add_argument('--auto-delete-artifacts', action='store_true')
    args = parser.parse_args([])
    dummy_main(args)