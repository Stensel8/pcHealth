using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace pcHealthPlus_VS
{
    public partial class Form1 : Form
    {
        public Form1()
        {
            InitializeComponent();
        }

            // Generic form loader:

        private void Form1_Load(object sender, EventArgs e)
        {

        }

        private void whatIsForm1(object sender, EventArgs e)
        {
            var Forms1 = new Form1();
        }

        // Menu items and their respective functions:

        private void label1_timeLoad(object sender, EventArgs e)
        {
            labelTimer1.Start();
            timeLabel.Text = DateTime.Now.ToString("HH:mm");
        }

        private void timeLabel_timer1(object sender, EventArgs e)
        {
            timeLabel.Text = DateTime.Now.ToString("HH:mm");
            labelTimer1.Start();
        }

        private void toolsToolStripMenuItem_Click(object sender, EventArgs e)
        {
            var Forms2 = new toolForm();
            Forms2.Show();
            this.Hide();
        }

        private void programMenu_ItemClicked(object sender, EventArgs e)
        {
            
        }

        private void programsToolStripMenuItem_Click(object sender, EventArgs e)
        {
            var Forms3 = new programForm();
            Forms3.Show();
            this.Hide();
        }

        private void helpToolStripMenuItem_Click(object sender, EventArgs e)
        {
            var Forms4 = new copyrightForm();
            Forms4.Show();
        }

        private void gitHubToolStripMenuItem_Click(object sender, EventArgs e)
        {
            System.Diagnostics.Process.Start("https://github.com/REALSDEALS/pcHealthPlus-VS");
        }

        private void quitToolStripMenuItem_onClick(object sender, EventArgs e)
        {
            Application.Exit();
        }

        // Side panel menu:

        private void toolsSideMenuBtn1_onClick(object sender, EventArgs e)
        {

        }

        private void programsSideMenuBtn2_onClick(object sender, EventArgs e)
        {

        }

        // Close Menu Items when new Menu is Opened

        private void closeMainMenu(object sender, EventArgs e)
        {

        }

        private void colourMenuPanel1_Paint(object sender, PaintEventArgs e)
        {

        }
    }
}
