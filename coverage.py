addrs = set(map(int, open("coverage.txt", "r").read().split()))
print "<html><body><pre>"
for line in open("json.lst", "r"):
    tokens = line.split()
    if int(tokens[1], 16) in addrs:
        print '<span style="background-color: #CFC">%s</span>' % line
    else:
        print '<span style="background-color: #FCC">%s</span>' % line
print "</pre></body></html>"


