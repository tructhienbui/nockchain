use std::sync::{Arc, Mutex};
use std::thread;
use num_cpus;
use crate::blockchain::{CandidateBlock, mine_block, meets_target, submit_block};

pub fn start_parallel_mining(candidate: CandidateBlock, other_args: ...) {
    let cpu_count = num_cpus::get();
    let candidate = Arc::new(candidate);
    let mining_stats = Arc::new(Mutex::new(MiningStats::default()));

    let mut handles = vec![];
    for worker_id in 0..cpu_count {
        let candidate = Arc::clone(&candidate);
        let stats = Arc::clone(&mining_stats);
        handles.push(thread::spawn(move || {
            let mut nonce = worker_id as u64;
            let step = cpu_count as u64;
            loop {
                let (found_nonce, hash) = mine_block(candidate.clone(), nonce, step, ...);
                if meets_target(&hash) {
                    submit_block(candidate.clone(), found_nonce, hash);
                    let mut stats = stats.lock().unwrap();
                    stats.found += 1;
                    break;
                }
                nonce += step;
            }
        }));
    }
    for handle in handles {
        let _ = handle.join();
    }
}

#[derive(Default)]
struct MiningStats {
    found: u64
}