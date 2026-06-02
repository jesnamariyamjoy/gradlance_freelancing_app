const fs = require('fs');
const path = require('path');

function walk(dir) {
    let results = [];
    const list = fs.readdirSync(dir);
    list.forEach(file => {
        const filePath = path.join(dir, file);
        const stat = fs.statSync(filePath);
        if (stat && stat.isDirectory()) {
            if (!filePath.includes('.git') && !filePath.includes('build') && !filePath.includes('.dart_tool')) {
                results = results.concat(walk(filePath));
            }
        } else if (filePath.endsWith('.dart')) {
            const content = fs.readFileSync(filePath, 'utf8');
            // Look for supabase insertions and updates
            const inserts = content.match(/from\(['"][a-zA-Z0-9_]+['"]\)\.insert\([\s\S]*?\)/g) || [];
            const updates = content.match(/from\(['"][a-zA-Z0-9_]+['"]\)\.update\([\s\S]*?\)/g) || [];
            let combined = [...inserts, ...updates];
            
            // Only alert if there is a number or date being passed loosely
            if (combined.length > 0) {
                console.log(`\n\n--- ${filePath} ---`);
                combined.forEach(m => console.log(m));
            }
        }
    });
    return results;
}

walk('c:/Jithin/BPC/GradlanceNew-18-03-16/MainApps');
