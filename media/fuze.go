// merge_videos.go
// Description: Normalize and merge multiple videos selected via fzf.
// Dependencies: fzf, ffmpeg, ffprobe
// Usage: go run merge_videos.go -o output.mp4

package main

import (
	"bufio"
	"bytes"
	"errors"
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync"
)

// Configurable parameters
var (
	outputName string
)

func init() {
	flag.StringVar(&outputName, "o", "merged_output.mp4", "Specify the output filename")
	flag.Usage = func() {
		fmt.Printf("Usage: %s [options]\n", os.Args[0])
		fmt.Println("Description: Normalize and merge multiple videos selected via fzf.")
		fmt.Println("Options:")
		fmt.Println("  -o OUTPUT   Specify the output filename (default: merged_output.mp4)")
		fmt.Println("  -h          Display this help message")
	}
}

func main() {
	flag.Parse()
	checkDependencies("fzf", "ffmpeg", "ffprobe")

	videoFiles, err := selectVideoFiles()
	if err != nil {
		log.Fatalf("Error selecting video files: %v", err)
	}
	if len(videoFiles) == 0 {
		log.Println("No video files selected. Exiting.")
		return
	}

	maxWidth, maxHeight, videoProps, err := analyzeVideos(videoFiles)
	if err != nil {
		log.Fatalf("Error analyzing videos: %v", err)
	}
	fmt.Printf("Target resolution: %dx%d\n", maxWidth, maxHeight)

	normalizedFiles, err := normalizeVideos(videoFiles, videoProps, maxWidth, maxHeight)
	if err != nil {
		log.Fatalf("Error normalizing videos: %v", err)
	}

	err = mergeVideos(normalizedFiles, outputName)
	if err != nil {
		log.Fatalf("Error merging videos: %v", err)
	}

	fmt.Printf("Videos merged successfully into '%s'.\n", outputName)
}

// checkDependencies verifies that all required commands are available.
func checkDependencies(commands ...string) {
	missing := []string{}
	for _, cmd := range commands {
		if _, err := exec.LookPath(cmd); err != nil {
			missing = append(missing, cmd)
		}
	}
	if len(missing) > 0 {
		log.Fatalf("Error: The following dependencies are missing: %s", strings.Join(missing, ", "))
	}
}

// selectVideoFiles uses fzf to allow the user to select multiple video files.
func selectVideoFiles() ([]string, error) {
	fmt.Println("Select video files to merge (use TAB to select multiple files):")
	cmd := exec.Command("fzf", "--multi", "--border", "--preview", "ffprobe -v error -show_entries stream=width,height -of default=noprint_wrappers=1 {}")
	cmd.Stdin = os.Stdin
	var out bytes.Buffer
	cmd.Stdout = &out
	if err := cmd.Run(); err != nil {
		return nil, err
	}
	files := strings.Split(strings.TrimSpace(out.String()), "\n")
	return files, nil
}

// analyzeVideos retrieves the maximum width and height among all selected videos and stores their properties.
func analyzeVideos(files []string) (int, int, map[string][2]int, error) {
	maxWidth, maxHeight := 0, 0
	videoProps := make(map[string][2]int)

	fmt.Println("Analyzing video properties...")

	for _, file := range files {
		if _, err := os.Stat(file); err != nil {
			return 0, 0, nil, fmt.Errorf("file '%s' does not exist", file)
		}

		width, height, err := getVideoDimensions(file)
		if err != nil {
			return 0, 0, nil, fmt.Errorf("could not retrieve properties for '%s': %v", file, err)
		}

		if width > maxWidth {
			maxWidth = width
		}
		if height > maxHeight {
			maxHeight = height
		}

		videoProps[file] = [2]int{width, height}
	}

	return maxWidth, maxHeight, videoProps, nil
}

// getVideoDimensions uses ffprobe to get the width and height of a video.
func getVideoDimensions(file string) (int, int, error) {
	cmd := exec.Command("ffprobe", "-v", "error", "-select_streams", "v:0",
		"-show_entries", "stream=width,height", "-of", "csv=p=0:s= ", file)
	output, err := cmd.Output()
	if err != nil {
		return 0, 0, err
	}
	parts := strings.Fields(strings.TrimSpace(string(output)))
	if len(parts) != 2 {
		return 0, 0, errors.New("invalid output from ffprobe")
	}
	width, err := strconv.Atoi(parts[0])
	if err != nil {
		return 0, 0, err
	}
	height, err := strconv.Atoi(parts[1])
	if err != nil {
		return 0, 0, err
	}
	return width, height, nil
}

// normalizeVideos scales and pads videos to the target resolution concurrently.
func normalizeVideos(files []string, props map[string][2]int, maxWidth, maxHeight int) ([]string, error) {
	fmt.Printf("Normalizing videos to resolution %dx%d...\n", maxWidth, maxHeight)
	var wg sync.WaitGroup
	normalizedFiles := make([]string, len(files))
	errChan := make(chan error, len(files))

	tmpDir, err := os.MkdirTemp("", "normalized_videos")
	if err != nil {
		return nil, err
	}
	defer os.RemoveAll(tmpDir)

	sem := make(chan struct{}, runtime.NumCPU())

	for i, file := range files {
		wg.Add(1)
		sem <- struct{}{}

		go func(i int, file string) {
			defer wg.Done()
			defer func() { <-sem }()

			width, height := props[file][0], props[file][1]
			baseName := filepath.Base(file)
			outputFile := filepath.Join(tmpDir, "normalized_"+baseName)

			if width != maxWidth || height != maxHeight {
				err := ffmpegNormalize(file, outputFile, maxWidth, maxHeight)
				if err != nil {
					errChan <- fmt.Errorf("error normalizing '%s': %v", file, err)
					return
				}
			} else {
				err := copyFile(file, outputFile)
				if err != nil {
					errChan <- fmt.Errorf("error copying '%s': %v", file, err)
					return
				}
			}
			normalizedFiles[i] = outputFile
		}(i, file)
	}

	wg.Wait()
	close(errChan)

	if len(errChan) > 0 {
		return nil, <-errChan
	}

	return normalizedFiles, nil
}

// ffmpegNormalize runs ffmpeg to scale and pad a video to the target resolution.
func ffmpegNormalize(inputFile, outputFile string, maxWidth, maxHeight int) error {
	args := []string{
		"-y", "-hide_banner", "-loglevel", "error",
		"-i", inputFile,
		"-vf", fmt.Sprintf("scale=%d:%d:force_original_aspect_ratio=decrease,pad=%d:%d:(ow-iw)/2:(oh-ih)/2", maxWidth, maxHeight, maxWidth, maxHeight),
		"-c:v", "libx264", "-preset", "fast", "-crf", "23",
		"-c:a", "aac", "-strict", "experimental",
		outputFile,
	}
	cmd := exec.Command("ffmpeg", args...)
	return cmd.Run()
}

// copyFile copies a file from src to dst.
func copyFile(src, dst string) error {
	input, err := os.Open(src)
	if err != nil {
		return err
	}
	defer input.Close()
	output, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer output.Close()
	_, err = ioCopy(output, input)
	return err
}

// ioCopy is a wrapper around io.Copy to handle any potential errors.
func ioCopy(dst *os.File, src *os.File) (int64, error) {
	return io.Copy(dst, src)
}

// mergeVideos concatenates normalized videos into a single output file.
func mergeVideos(files []string, output string) error {
	tmpDir, err := os.MkdirTemp("", "concat")
	if err != nil {
		return err
	}
	defer os.RemoveAll(tmpDir)

	concatFile := filepath.Join(tmpDir, "concat_list.txt")
	f, err := os.Create(concatFile)
	if err != nil {
		return err
	}
	defer f.Close()

	for _, file := range files {
		if _, err := os.Stat(file); err != nil {
			return fmt.Errorf("normalized file '%s' not found", file)
		}
		_, err = f.WriteString(fmt.Sprintf("file '%s'\n", file))
		if err != nil {
			return err
		}
	}

	args := []string{
		"-y", "-hide_banner", "-loglevel", "error",
		"-f", "concat", "-safe", "0",
		"-i", concatFile,
		"-c", "copy",
		output,
	}
	cmd := exec.Command("ffmpeg", args...)
	return cmd.Run()
}
