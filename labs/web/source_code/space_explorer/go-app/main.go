package main

import (
	"bytes"
	"encoding/json"
	"io"
	"log"
	"net/http"
)

type RequestData struct {
	Action string `json:"action"`
}

func homeHandler(w http.ResponseWriter, r *http.Request) {
	html := `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Cosmic Explorer</title>
    <style>
        :root {
            --space-dark: #0B0D21;
            --neon-blue: #00F0FF;
            --neon-purple: #BD00FF;
            --alert-red: #FF2D75;
        }
        
        body {
            font-family: 'Orbitron', sans-serif;
            background-color: var(--space-dark);
            color: white;
            background-image: 
                radial-gradient(circle at 20% 30%, rgba(189, 0, 255, 0.15) 0%, transparent 50%),
                radial-gradient(circle at 80% 70%, rgba(0, 240, 255, 0.15) 0%, transparent 50%),
                url('data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100"><circle cx="20" cy="20" r="0.5" fill="white"/><circle cx="50" cy="80" r="0.8" fill="white"/><circle cx="90" cy="30" r="0.3" fill="white"/></svg>');
            min-height: 100vh;
            margin: 0;
            padding: 2rem;
        }
        
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: rgba(11, 13, 33, 0.8);
            border: 1px solid var(--neon-blue);
            box-shadow: 0 0 20px rgba(0, 240, 255, 0.3);
            border-radius: 10px;
            padding: 2rem;
            backdrop-filter: blur(5px);
        }
        
        h1 {
            color: var(--neon-blue);
            text-align: center;
            text-shadow: 0 0 10px var(--neon-blue);
            margin-bottom: 2rem;
            font-weight: 700;
        }
        
        .options {
            display: flex;
            flex-direction: column;
            gap: 1rem;
            margin-bottom: 2rem;
        }
        
        .option {
            padding: 1rem;
            border: 1px solid var(--neon-purple);
            border-radius: 5px;
            cursor: pointer;
            transition: all 0.3s;
            background: rgba(189, 0, 255, 0.05);
        }
        
        .option:hover {
            background: rgba(189, 0, 255, 0.2);
            box-shadow: 0 0 15px rgba(189, 0, 255, 0.3);
        }
        
        .option input[type="radio"] {
            accent-color: var(--neon-blue);
            margin-right: 1rem;
        }
        
        .btn {
            background: linear-gradient(90deg, var(--neon-blue), var(--neon-purple));
            color: black;
            border: none;
            padding: 0.8rem;
            font-weight: bold;
            border-radius: 5px;
            cursor: pointer;
            width: 100%;
            font-family: 'Orbitron', sans-serif;
            letter-spacing: 1px;
            transition: all 0.3s;
        }
        
        .btn:hover {
            box-shadow: 0 0 20px rgba(0, 240, 255, 0.5);
        }
        
        #result-container {
            margin-top: 2rem;
            min-height: 300px;
            border: 1px dashed var(--neon-blue);
            border-radius: 5px;
            padding: 1rem;
            position: relative;
            overflow: hidden;
        }
        
        #result-container::before {
            content: "";
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 1px;
            background: linear-gradient(90deg, transparent, var(--neon-blue), transparent);
            animation: scanline 3s linear infinite;
        }
        
        @keyframes scanline {
            0% { top: 0; }
            100% { top: 100%; }
        }
        
        .cosmic-image {
            max-width: 100%;
            border-radius: 5px;
            border: 1px solid var(--neon-purple);
            box-shadow: 0 0 20px rgba(189, 0, 255, 0.3);
            margin-top: 1rem;
        }
        
        .alert {
            color: var(--alert-red);
            text-shadow: 0 0 5px var(--alert-red);
            font-weight: bold;
        }
    </style>
    <link href="https://fonts.googleapis.com/css2?family=Orbitron:wght@400;700&display=swap" rel="stylesheet">
</head>
<body>
    <div class="container">
        <h1>COSMIC EXPLORER</h1>
        
        <div class="options">
            <label class="option">
                <input type="radio" name="action" value="getcosmic" id="getcosmic">
                Scan Cosmic Anomaly
            </label>
            
            <label class="option">
                <input type="radio" name="action" value="getSecureCode" id="getSecureCode">
                <span class="alert">ACCESS SECURE DATABASE</span>
            </label>
        </div>
        
        <button class="btn" onclick="sendRequest()">INITIATE SCAN</button>
        
        <div id="result-container">
            <p style="text-align: center;">Awaiting scan results...</p>
        </div>
    </div>
    
    <script>
        function sendRequest() {
            const selectedOption = document.querySelector('input[name="action"]:checked');
            if (!selectedOption) {
                alert("SELECTION REQUIRED");
                return;
            }

            fetch("/execute", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ action: selectedOption.value })
            })
            .then(response => response.text().then(text => ({ text, response })))
            .then(({ text, response }) => {
                const resultContainer = document.getElementById("result-container");
                resultContainer.innerHTML = "";
                
                try {
                    const data = JSON.parse(text);
                    if (data.flag) {
                        resultContainer.innerHTML = '<h3 style="color: var(--alert-red);">SECURE DATABASE ACCESSED</h3><div style="background: rgba(255,45,117,0.1); padding: 1rem; border-radius: 5px;">' + data.flag + '</div>';
                    } else if (data.name && data.src) {
                        resultContainer.innerHTML = '<h3 style="color: var(--neon-blue);">ANOMALY DETECTED:</h3><p>' + data.name + '</p><img src="' + data.src + '" class="cosmic-image" alt="Cosmic anomaly">';
                    }
                } catch (error) {
                    resultContainer.innerHTML = '<p class="alert">ERROR: ' + text + '</p>';
                }
            })
            .catch(error => {
                document.getElementById("result-container").innerHTML = '<p class="alert">SYSTEM OFFLINE</p>';
            });
        }
    </script>
</body>
</html>`
	w.Header().Set("Content-Type", "text/html")
	w.Write([]byte(html))
}

func executeHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Invalid request method", http.StatusMethodNotAllowed)
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Failed to read request body", http.StatusBadRequest)
		return
	}

	var requestData RequestData
	if err := json.Unmarshal(body, &requestData); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	switch requestData.Action {
	case "getcosmic":
		resp, err := http.Post("http://localhost:8081/execute", "application/json", bytes.NewBuffer(body))
		if err != nil {
			log.Printf("Failed to reach cosmic scanner: %v", err)
			http.Error(w, "Scanner offline", http.StatusInternalServerError)
			return
		}
		defer resp.Body.Close()
		io.Copy(w, resp.Body)
	case "getSecureCode":
		w.Write([]byte("Access denied: Invalid security clearance"))
	default:
		http.Error(w, "Invalid command", http.StatusBadRequest)
	}
}

func main() {
	http.HandleFunc("/", homeHandler)
	http.HandleFunc("/execute", executeHandler)

	log.Println("Cosmic Explorer running on http://localhost:8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
