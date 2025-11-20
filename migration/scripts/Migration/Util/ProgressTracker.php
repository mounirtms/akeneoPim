<?php

namespace Migration\Util;

class ProgressTracker
{
    private $total;
    private $current = 0;
    private $lastUpdate = 0;
    private $startTime;
    private $name;
    
    public function __construct($total, $name = 'Progress')
    {
        $this->total = $total;
        $this->name = $name;
        $this->startTime = microtime(true);
        $this->updateProgress(0);
    }
    
    public function increment($amount = 1)
    {
        $this->current += $amount;
        $this->updateProgress();
    }
    
    private function updateProgress()
    {
        $now = microtime(true);
        // Update every 1 second or when complete
        if ($now - $this->lastUpdate >= 1 || $this->current >= $this->total) {
            $percent = ($this->total > 0) ? round(($this->current / $this->total) * 100, 1) : 0;
            $elapsed = $now - $this->startTime;
            $rate = ($elapsed > 0) ? round($this->current / $elapsed, 2) : 0;
            $eta = ($rate > 0) ? round(($this->total - $this->current) / $rate) : 0;
            
            echo sprintf("\r%s: [%-50s] %d/%d (%s%%) - %s/s - ETA: %s     ",
                $this->name,
                str_repeat('=', floor($percent / 2)) . '>',
                $this->current,
                $this->total,
                $percent,
                $rate,
                $this->formatTime($eta)
            );
            
            if ($this->current >= $this->total) {
                echo "\nCompleted in " . round($elapsed, 2) . " seconds\n";
            }
            
            $this->lastUpdate = $now;
        }
    }
    
    private function formatTime($seconds)
    {
        if ($seconds < 60) {
            return round($seconds) . 's';
        } elseif ($seconds < 3600) {
            return round($seconds / 60) . 'm';
        } else {
            return round($seconds / 3600, 1) . 'h';
        }
    }
}